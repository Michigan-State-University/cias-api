# frozen_string_literal: true

FactoryBot.define do
  factory :report_template_section, class: 'ReportTemplate::Section' do
    formula { 'var100 + var200' }
    association(:report_template)

    trait :with_variant do
      after(:create) do |section|
        section.variants << create(:report_template_section_variant, :with_image)
      end
    end
  end
end
