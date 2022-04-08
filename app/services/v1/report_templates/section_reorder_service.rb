# frozen_string_literal: true

class V1::ReportTemplates::SectionReorderService
  def self.call(report_template_id, params)
    new(report_template_id, params).call
  end

  def initialize(report_template_id, params)
    @sections = ReportTemplate.find(report_template_id).sections
    @params = params
  end

  def call
    ReportTemplate::Section.transaction do
      params.each { |param| sections.find(param['id']).update!(position: param['position']) }
    end
  end

  private

  attr_reader :report_template, :params
  attr_accessor :sections
end
