# frozen_string_literal: true

FactoryBot.define do
  factory :sms_link, class: SmsLink do
    association(:session)
    association(:sms_plan)
    sequence(:url) { 'google.com' }
    sequence(:link_type) { 'website' }
    sequence(:variable) { |n| "link_variable_#{n}" }

    trait :with_variant do
      association(:variant, factory: :sms_plan_variant)
      sms_plan { variant.sms_plan }
      session { variant.sms_plan.session }
    end
  end
end
