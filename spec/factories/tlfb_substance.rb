# frozen_string_literal: true

FactoryBot.define do
  factory :tlfb_substance, class: Tlfb::Substance do
    body { {} }
    association(:day)
  end
end
