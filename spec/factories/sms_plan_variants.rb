# frozen_string_literal: true

FactoryBot.define do
  factory :sms_plan_variant, class: 'SmsPlan::Variant' do
    sequence(:content) { |n| "some_content#{n}" }
    sequence(:formula_match) { |n| "#{%w[= < > <= >=].sample}#{n}" }
    association(:sms_plan)
  end
end
