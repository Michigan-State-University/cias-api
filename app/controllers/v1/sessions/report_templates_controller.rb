# frozen_string_literal: true

class V1::Sessions::ReportTemplatesController < V1Controller
  load_and_authorize_resource :session

  def index
    authorize! :read, ReportTemplate

    render json: serialized_response(report_templates_scope)
  end

  def show
    authorize! :read, report_template

    render json: V1::ReportTemplateSerializer.new(
      report_template,
      { include: %i[sections variants] }
    )
  end

  def create
    authorize! :create, ReportTemplate
    authorize! :update, @session

    return head :forbidden unless correct_ability?

    new_report_template = V1::ReportTemplates::Create.call(
      report_template_params,
      @session
    )

    render json: serialized_response(new_report_template), status: :created
  end

  def update
    authorize! :update, report_template

    return head :forbidden unless correct_ability?

    V1::ReportTemplates::Update.call(
      report_template,
      report_template_params
    )

    render json: V1::ReportTemplateSerializer.new(
      report_template.reload,
      { include: %i[sections variants] }
    )
  end

  def destroy
    authorize! :destroy, report_template

    return head :forbidden unless correct_ability?

    report_template.destroy!
    head :no_content
  end

  def remove_logo
    authorize! :remove_logo, report_template

    return head :forbidden unless correct_ability?

    report_template.logo.purge

    render status: :no_content
  end

  def remove_cover_letter_custom_logo
    authorize! :remove_cover_letter_custom_logo, report_template

    return head :forbidden unless correct_ability?

    report_template.cover_letter_custom_logo.purge

    render status: :no_content
  end

  def duplicate
    authorize! :update, @session
    return head :forbidden unless @session.ability_to_update_for?(current_v1_user)

    duplicated_report = report_template.clone(params: duplicate_params)
    Session.reset_counters(duplicated_report.session.id, :report_templates)

    render json: serialized_response(duplicated_report), status: :created
  end

  private

  def report_template
    @report_template ||= report_template_included_scope.find(params[:id] || params[:report_template_id])
  end

  def report_templates_scope
    @report_templates_scope ||= @session.report_templates.includes(%i[logo_attachment sections variants])
  end

  def report_template_included_scope
    # rubocop:disable Naming/MemoizedInstanceVariableName
    @report_templates_included_scope ||= @session.report_templates.includes(
      :variants,
      { logo_attachment: :blob, pdf_preview_blob: :blob, pdf_preview_attachment: :blob,
        sections: [:variants, { variants: [image_attachment: :blob] }] }
    )
    # rubocop:enable Naming/MemoizedInstanceVariableName
  end

  def report_template_params
    params.require(:report_template).
      permit(:name, :report_for, :logo, :cover_letter_custom_logo, :summary,
             :has_cover_letter, :cover_letter_logo_type, :cover_letter_description, :cover_letter_sender,
             :duplicated_from_other_session_warning_dismissed)
  end

  def correct_ability?
    @session.ability_to_update_for?(current_v1_user)
  end

  def target_session
    @target_session ||= if params.dig(:report_template, :session_id).present?
                          Session.find(params[:report_template][:session_id])
                        else
                          @session
                        end
  end

  def duplicate_params
    target_session.present? ? { session_id: target_session.id } : {}
  end
end
