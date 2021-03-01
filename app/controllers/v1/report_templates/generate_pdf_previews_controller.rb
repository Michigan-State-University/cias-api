# frozen_string_literal: true

class V1::ReportTemplates::GeneratePdfPreviewsController < V1Controller
  def create
    authorize! :generate_pdf_preview, report_template

    ReportTemplates::GeneratePdfPreviewJob.perform_later(
      report_template.id,
      current_v1_user.id
    )

    render status: :created
  end

  private

  def report_template
    @report_template ||= ReportTemplate.accessible_by(current_ability).find_by(id: params[:report_template_id])
  end
end
