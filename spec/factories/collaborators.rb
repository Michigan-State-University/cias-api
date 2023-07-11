# frozen_string_literal: true

FactoryBot.define do
  factory :collaborator do
    view { true }
    edit { true }
    data_access { false }
    association(:user)
    association(:intervention)
  end
end
