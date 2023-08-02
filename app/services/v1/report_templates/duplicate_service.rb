# frozen_string_literal: true

class V1::ReportTemplates::DuplicateService
  def self.call(report_template, target_session)
    new(report_template, target_session).call
  end

  def initialize(report_template, target_session)
    @report_template = report_template
    @target_session = target_session
  end

  def call; end

  attr_reader :report_template
  attr_accessor :target_session
end
