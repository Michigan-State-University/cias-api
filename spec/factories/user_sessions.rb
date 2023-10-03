# frozen_string_literal: true

FactoryBot.define do
  factory :user_session do
    type { UserSession::Classic }
    association :user
    association :session
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
