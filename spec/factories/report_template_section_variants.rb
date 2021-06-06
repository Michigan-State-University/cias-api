# frozen_string_literal: true

FactoryBot.define do
  factory :report_template_section_variant, class: 'ReportTemplate::Section::Variant' do
    title                    { Faker::Movie.title }
    content                  { Faker::Quote.matz }
    sequence(:formula_match) { |n| "#{%w[= < > <= >=].sample}#{n}" }
    preview                  { false }
    association(:report_template_section)

    trait :to_preview do
      preview { true }
    end

    trait :with_image do
      after(:create) do |report_template|
        report_template.update(
          image: fixture_file_upload("#{Rails.root}/spec/fixtures/images/logo.png", 'image/png')
        )
      end
    end
  end
end
