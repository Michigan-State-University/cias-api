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

    new_report_template = V1::ReportTemplates::Create.call(
      report_template_params,
      @session
    )

    render json: serialized_response(new_report_template), status: :created
  end

  def update
    authorize! :update, report_template

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

    report_template.destroy!
    head :no_content
  end

  def remove_logo
    authorize! :remove_logo, report_template

    report_template.logo.purge

    render status: :ok
  end

  private

  def report_template
    @report_template ||= report_template_included_scope.find(params[:id] || params[:report_template_id])
  end

  def report_templates_scope
    @report_templates_scope ||= @session.report_templates.includes([:logo_attachment])
  end

  def report_template_included_scope
    @report_templates_included_scope ||= @session.report_templates.includes([:logo_attachment, { sections: [:variants, { variants: [:image_attachment] }] }]) # rubocop:disable Naming/MemoizedInstanceVariableName
  end

  def report_template_params
    params.require(:report_template).
      permit(:name, :report_for, :logo, :summary)
  end
end
