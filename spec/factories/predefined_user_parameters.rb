# frozen_string_literal: true

FactoryBot.define do
  factory :predefined_user_parameter do
    association(:intervention)
    association(:user)
  end
end
