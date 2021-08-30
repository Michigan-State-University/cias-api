# frozen_string_literal: true

FactoryBot.define do
  factory :cat_mh_test_type do
    name { 'mdd' }
    association :cat_mh_population
  end
end
