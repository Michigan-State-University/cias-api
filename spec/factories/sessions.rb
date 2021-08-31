# frozen_string_literal: true

FactoryBot.define do
  factory :session do
    sequence(:name) { |s| "session_#{s}" }
    sequence(:variable) { |s| "session_#{s}" }
    sequence(:position) { |s| s }
    association :intervention

    trait :with_questions do
      question { create_list(:question, 5) }
    end

    trait :with_answers do
      answers { create_list(:answer, 5) }
    end

    trait :with_report_templates do
      report_templates { create_list(:report_template, 2, :with_logo, :with_sections) }
    end

    trait :with_sms_plans do
      sms_plans { create_list(:sms_plan, 2) }
    end

    trait :with_sms_plans_with_text do
      sms_plans { create_list(:sms_plan_with_text, 2) }
    end

    trait :days_after do
      schedule { 'days_after' }
      schedule_payload { 7 }
    end

    trait :days_after_fill do
      schedule { 'days_after_fill' }
    end

    trait :exact_date do
      schedule { 'exact_date' }
      schedule_at { Date.current + 7 }
    end

    trait :days_after_date do
      schedule { 'days_after_date' }
      schedule_payload { 7 }
    end
  end

  factory :cat_mh_session, class: Session::CatMh do
    sequence(:name) { |s| "session_#{s}" }
    sequence(:variable) { |s| "session_#{s}" }
    sequence(:position) { |s| s }
    association :intervention

    trait :with_test_type_and_variables do
      after(:build) do |session|
        test_type = create(:cat_mh_test_type, name: 'Depression', short_name: 'dep')
        test_type.cat_mh_test_attributes << CatMhTestAttribute.create(name: 'severity', variable_type: 'number', range: '0-100')
        test_type.cat_mh_test_attributes << CatMhTestAttribute.create(name: 'precision', variable_type: 'number', range: '0-100')
        session.cat_mh_test_types << test_type
      end
    end

    trait :with_cat_mh_info do
      after(:build) do |session|
        language = CatMhLanguage.create(language_id: 1, name: 'English')
        time_frame = CatMhTimeFrame.create(timeframe_id: 1, description: 'Past hour', short_name: '1h')
        population = CatMhPopulation.create(name: 'General')

        session.update(cat_mh_language: language, cat_mh_time_frame: time_frame, cat_mh_population: population)
      end
    end
  end
end
