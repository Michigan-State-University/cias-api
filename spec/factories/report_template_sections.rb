# frozen_string_literal: true

FactoryBot.define do
  factory :report_template_section, class: 'ReportTemplate::Section' do
    formula { 'var100 + var200' }
    association(:report_template)
  end
end
