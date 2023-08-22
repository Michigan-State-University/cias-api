# frozen_string_literal: true

class V1::Interventions::StarsController < V1Controller
  def make_starred
    authorize! :read, Intervention

    current_v1_user.stars.find_or_create_by(intervention_id: intervention_load.id)

    render json: serialized_response(intervention_load, "Intervention", params: { current_user_id: current_v1_user.id })
  end

  def make_unstarred
    authorize! :read, Intervention

    current_v1_user.stars.delete_by(intervention_id: intervention_load.id)

    render json: serialized_response(intervention_load, "Intervention", params: { current_user_id: current_v1_user.id })
  end

  private

  def interventions_scope
    @interventions_scope ||= Intervention.accessible_by(current_ability)
                                         .order(created_at: :desc)
                                         .includes(%i[user reports_attachments files_attachments google_language logo_attachment logo_blob collaborators
                                                      conversations_transcript_attachment stars])
                                         .only_visible
  end

  def intervention_load
    @intervention_load ||= interventions_scope.find(params[:id])
  end
end
