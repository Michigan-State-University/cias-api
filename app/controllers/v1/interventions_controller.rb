# frozen_string_literal: true

class V1::InterventionsController < V1Controller
  def index
    collection = sorted_interventions_scope.detailed_search(params, current_v1_user)

    paginated_collection = V1::Paginate.call(collection, start_index, end_index)

    starred_interventions_ids = current_v1_user.stars.pluck(:intervention_id)

    render json: serialized_hash(paginated_collection, 'SimpleIntervention', params: {
                                   starred_interventions_ids: starred_interventions_ids, current_user_id: current_v1_user.id
                                 }).merge({ interventions_size: collection.size }).to_json
  end

  def show
    render json: V1::InterventionSerializer.new(
      intervention_load,
      { include: [:tags], params: { current_user_id: current_v1_user.id } }
    ).serializable_hash.to_json
  end

  def create
    authorize! :create, Intervention

    intervention = current_v1_user.interventions.create!(intervention_params)
    render json: serialized_response(intervention, controller_name.classify, params: { current_user_id: current_v1_user.id }), status: :created
  end

  def update
    authorize! :update, Intervention
    authorize! :update, intervention_load
    return head :forbidden unless intervention_load.ability_to_update_for?(current_v1_user)

    intervention = V1::Intervention::Update.new(intervention_load, intervention_params).execute

    render json: serialized_hash(intervention, controller_name.classify, params: { current_user_id: current_v1_user.id })
  end

  def clone
    authorize! :update, Intervention

    CloneJobs::Intervention.perform_later(current_v1_user, params[:id], clone_params)

    render status: :ok
  end

  def generate_conversations_transcript
    authorize! :update, Intervention
    authorize! :get_protected_attachment, intervention_load

    LiveChat::GenerateTranscriptJob.perform_later(
      intervention_load.id, ::Intervention, :conversations_transcript, intervention_load.name, current_v1_user.id
    )

    render status: :ok
  end

  def generated_conversations_transcript
    authorize! :read, Intervention
    authorize! :get_protected_attachment, intervention_load

    head :no_content unless intervention_load.conversations_transcript.attached?

    redirect_to(ENV.fetch('APP_HOSTNAME', nil) + Rails.application.routes.url_helpers.rails_blob_path(
      intervention_load.conversations_transcript, only_path: true
    ), allow_other_host: true)
  end

  def clear_user_data
    authorize! :clear_protected_intervention, intervention_load

    return head :forbidden unless intervention_load.sensitive_data_collected?
    return head :forbidden unless clear_data_ability?

    DataClearJobs::ClearUserData.set(wait: number_of_days_to_remove.days).perform_later(intervention_load.id)
    intervention_load.update!(sensitive_data_state: 'marked_to_remove', clear_sensitive_data_scheduled_at: DateTime.now + number_of_days_to_remove.days)

    render json: serialized_response(intervention_load)
  end

  private

  def interventions_scope
    @interventions_scope ||= Intervention.accessible_by(current_ability)
                                         .with_attached_logo
                                         .with_attached_exported_data
                                         .includes([:user, :reports_attachments, :files_attachments, :google_language,
                                                    :logo_attachment, :logo_blob, :collaborators,
                                                    :conversations_transcript_attachment, { tags: :tag_interventions }])
                                         .only_visible
  end

  def sorted_interventions_scope
    @sorted_interventions_scope ||= Intervention.accessible_by(current_ability)
                                                .joins("LEFT JOIN stars AS user_stars ON user_stars.intervention_id = interventions.id AND user_stars.user_id = '#{current_v1_user.id}'") # rubocop:disable Layout/LineLength
                                                .order(Arel.sql('(user_stars.id IS NOT NULL) DESC'), 'interventions.created_at DESC')
                                                .order('interventions.created_at DESC')
                                                .only_visible
  end

  def intervention_load
    @intervention_load ||= interventions_scope.find(params[:id])
  end

  def intervention_params
    if params[:id].present? && intervention_load.published?
      params.expect(intervention: [:status, :cat_mh_pool, :is_access_revoked, :live_chat_enabled, { location_ids: [] }])
    elsif current_v1_user.admin?
      params.expect(intervention: [:name, :status, :type, :shared_to, :additional_text, :organization_id, :google_language_id,
                                   :cat_mh_application_id, :cat_mh_organization_id, :cat_mh_pool, :is_access_revoked, :license_type, :quick_exit,
                                   :hfhs_access, :live_chat_enabled, :note, { location_ids: [] }])
    else
      params.expect(intervention: [:name, :status, :type, :shared_to, :additional_text, :organization_id, :google_language_id,
                                   :cat_mh_application_id, :cat_mh_organization_id, :cat_mh_pool, :is_access_revoked, :license_type, :live_chat_enabled,
                                   :quick_exit, :note, { location_ids: [] }])
    end
  end

  def start_index
    params.permit(:start_index)[:start_index]&.to_i
  end

  def end_index
    params.permit(:end_index)[:end_index]&.to_i
  end

  def clone_params
    key = controller_name.singularize.to_sym
    params.fetch(key, {}).permit(*to_permit[key])
  end

  def to_permit
    @to_permit ||= {
      intervention: [{ emails: [] }],
      session: [],
      question: [],
      sms_plan: []
    }
  end

  def clear_data_ability?
    intervention_load.ability_to_update_for?(current_v1_user) && intervention_load.user_id == current_v1_user.id && intervention_load.status.in?(%w[closed
                                                                                                                                                    archived])
  end

  def number_of_days_to_remove
    params[:delay].to_i
  end
end
