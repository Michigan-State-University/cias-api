# frozen_string_literal: true

class ReportTemplates::GeneratePdfPreviewJob < ApplicationJob
  queue_as :reports

  def perform(report_template_id, current_v1_user_id)
    V1::ReportTemplates::GeneratePdfPreview.call(
      ReportTemplate.find(report_template_id),
      User.find(current_v1_user_id)
    )
  end
end
