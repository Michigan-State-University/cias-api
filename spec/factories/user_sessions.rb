# frozen_string_literal: true

FactoryBot.define do
  factory :user_session do
    association :user
    association :session
  end

  factory :user_session_cat_mh, class: UserSession::CatMh do
    type { UserSession::CatMh }
    association :user
    association :session
  end
end
