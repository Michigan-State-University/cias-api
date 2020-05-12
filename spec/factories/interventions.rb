# frozen_string_literal: true

FactoryBot.define do
  factory :intervention do
    user
    factory :intervention_single, class: 'Intervention::Single' do
      name { 'Single' }
      type { Intervention::Single }
    end

    factory :intervention_multiple, class: 'Intervention::Multiple' do
      name { 'Multiple' }
      type { Intervention::Multiple }
    end
  end
end
