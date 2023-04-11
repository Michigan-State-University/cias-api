# frozen_string_literal: true

FactoryBot.define do
  factory :sms_plan_variant, class: 'SmsPlan::Variant' do
    sequence(:content) { |n| "some_content#{n}" }
    sequence(:formula_match) { |n| "#{%w[= < > <= >=].sample}#{n}" }
    association(:sms_plan)

    trait :with_image do
      image { FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg') }
    end
  end
end
