# frozen_string_literal: true

FactoryBot.define do
  factory :user_session do
    association :user
    association :session
  end
end
