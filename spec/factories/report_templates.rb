# frozen_string_literal: true

FactoryBot.define do
  factory :report_template do
    name       { Faker::Name.name }
    report_for { 'third_party' }
    summary    { 'Your session summary' }
    association(:session)

    trait :with_logo do
      after(:create) do |report_template|
        report_template.update(
          logo: fixture_file_upload("#{Rails.root}/spec/fixtures/images/logo.png", 'image/png')
        )
      end
    end
  end
end
