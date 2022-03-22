# frozen_string_literal: true

FactoryBot.define do
  factory :tlfb_consumption_result, class: Tlfb::ConsumptionResult do
    body { {} }
    association(:day)
  end
end
