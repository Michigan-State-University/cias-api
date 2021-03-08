# frozen_string_literal: true

FactoryBot.define do
  factory :generated_report do
    name       { Faker::Name.name }
    report_for { 'third_party' }
    association(:report_template)
    association(:user_session)

    trait(:third_party) do
      report_for { 'third_party' }
    end

    trait(:participant) do
      report_for { 'participant' }
    end

    trait(:shared_with_participant) do
      participant_id { create(:user, :confirmed, :participant) }
    end

    trait(:shared_with_third_party) do
      participant_id { create(:user, :confirmed, :participant) }
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
