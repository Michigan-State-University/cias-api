# frozen_string_literal: true

FactoryBot.define do
  factory :address, class: Address do
    user
  end
end
