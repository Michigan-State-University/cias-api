# frozen_string_literal: true

class V1::ReportTemplates::Create
  def self.call(report_template_params, session)
    new(report_template_params, session).call
  end

  def initialize(report_template_params, session)
    @report_template_params = report_template_params
    @session                = session
  end

  def call
    ReportTemplate.create!(
      name: report_name,
      session_id: session.id,
      **report_template_params
    )
  end

  private

  attr_reader :report_template_params, :session

  def report_name
    report_template_params.delete(:name).presence || "New Report #{report_number}"
  end

  def report_number
    session.report_templates_count.to_i + 1
  end
end
