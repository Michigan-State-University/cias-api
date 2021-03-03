# frozen_string_literal: true

FactoryBot.define do
  factory :generated_report do
    name       { Faker::Name.name }
    report_for { 'third_party' }
    shown_for_participant { false }
    association(:report_template)
    association(:user_session)

    trait(:third_party) do
      report_for { 'third_party' }
    end

    trait(:participant) do
      report_for { 'participant' }
    end

    trait(:shown_for_participant) do
      shown_for_participant { true }
    end

    trait(:not_shown_for_participant) do
      shown_for_participant { false }
    end

    trait(:shared_to_third_party) do
      third_party_id { create(:user, :confirmed, :third_party).id }
    end

    trait :with_pdf_report do
      after(:create) do |report_template|
        report_template.update(
          pdf_report: fixture_file_upload("#{Rails.root}/spec/fixtures/pdf/example_report.pdf", 'application/pdf')
        )
      end
    end
  end
end
