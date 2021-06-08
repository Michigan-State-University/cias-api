# frozen_string_literal: true

FactoryBot.define do
  factory :generated_report do
    name       { Faker::Name.name }
    report_for { 'third_party' }
    association(:report_template)
    association(:user_session)

    trait(:third_party) do
      report_for { 'third_party' }

      transient do
        third_party_id { nil }
      end

      after(:create) do |report, evaluator|
        if evaluator.third_party_id
          report.generated_reports_third_party_users.create(
            third_party_id: evaluator.third_party_id
          )
        end
      end
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
      after(:create) do |report, _|
        report.third_party_users << create(:user, :confirmed, :third_party)
      end
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
