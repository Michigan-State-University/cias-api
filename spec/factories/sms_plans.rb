# frozen_string_literal: true

FactoryBot.define do
  factory :sms_plan, class: SmsPlan::Normal do
    association(:session)
    sequence(:name) { |s| "sms_plan#{s}" }
    schedule { SmsPlan.schedules[:after_session_end] }
    frequency { SmsPlan.frequencies[:once] }

    trait :with_no_formula_image do
      no_formula_image { FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg') }
    end
  end

  factory :sms_plan_with_text, class: SmsPlan::Normal do
    association(:session)
    sequence(:name) { |s| "sms_plan#{s}" }
    no_formula_text { 'Example text' }
    schedule { SmsPlan.schedules[:after_session_end] }
    frequency { SmsPlan.frequencies[:once] }
  end

  factory :sms_alert, class: SmsPlan::Alert do
    association(:session)
    sequence(:name) { |s| "sms_plan#{s}" }
    no_formula_text { 'Example' }
    schedule { SmsPlan.schedules[:after_session_end] }
    frequency { SmsPlan.frequencies[:once] }
  end

  factory :alert_with_personal_data, class: SmsPlan::Alert do
    association(:session)
    sequence(:name) { |s| "sms_plan#{s}" }
    no_formula_text { 'Example' }
    schedule { SmsPlan.schedules[:after_session_end] }
    frequency { SmsPlan.frequencies[:once] }

    include_first_name { true }
    include_last_name { true }
    include_email { true }
    include_phone_number { true }
  end
end
