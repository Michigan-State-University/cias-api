# frozen_string_literal: true

FactoryBot.define do
  factory :tlfb_day, class: Tlfb::Day do
    exact_date { DateTime.now }
    association :question_group
    association :user_session
  end
end
