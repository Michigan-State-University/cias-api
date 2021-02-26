# frozen_string_literal: true

class V1::ReportTemplates::Update
  def self.call(report_template, params)
    new(report_template, params).call
  end

  def initialize(report_template, params)
    @report_template = report_template
    @params          = params
  end

  def call
    report_template.update!(
      params
    )
  end

  private

  attr_reader :report_template, :params
end
