# frozen_string_literal: true

FactoryBot.define do
  factory :user_session do
    type { UserSession::Classic }
    association :user
    association :session
    association :user_intervention
    multiple_fill { false }
  end

  factory :sms_user_session, class: UserSession::Sms do
    type { UserSession::Sms }
    association :user
    association :session
    association :user_intervention
    multiple_fill { false }
    sms_phone_prefix { nil }
    sms_phone_number { nil }

    trait :with_phone do
      sms_phone_prefix { '+1' }
      sms_phone_number { '5551234567' }
    end
  end

  factory :ra_user_session, class: UserSession::ResearchAssistant do
    type { UserSession::ResearchAssistant }
    association :user
    association :session, factory: :ra_session
    association :user_intervention
    multiple_fill { false }
  end

  factory :user_session_cat_mh, class: UserSession::CatMh do
    type { UserSession::CatMh }
    association :user
    association :session
    association :user_intervention
  end
end
