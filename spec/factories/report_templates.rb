# frozen_string_literal: true

FactoryBot.define do
  factory :report_template do
    name       { Faker::Name.name }
    report_for { 'third_party' }
    summary    { 'Your session summary' }
    association(:session)

    trait :third_party do
      report_for { 'third_party' }
    end

    trait :participant do
      report_for { 'participant' }
    end

    trait :with_logo do
      after(:create) do |report_template|
        report_template.update(
          logo: FactoryHelpers.upload_file('spec/fixtures/images/logo.png', 'image/png', true)
        )
      end
    end

    trait :with_sections do
      after(:create) do |report_template|
        report_template.sections << create(:report_template_section, :with_variant)
      end
    end
  end
end
