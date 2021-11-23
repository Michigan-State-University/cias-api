# frozen_string_literal: true

FactoryBot.define do
  factory :intervention do
    user
    name { 'Intervention' }
    trait :published do
      status { 'published' }
    end
    trait :closed do
      status { 'closed' }
    end
    trait :archived do
      status { 'archived' }
    end
    shared_to { 'anyone' }
  end

  factory :intervention_with_logo, class: Intervention do
    user
    name { 'Intervention with logo' }
    logo { FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg') }
    trait :published do
      status { 'published' }
    end
    trait :closed do
      status { 'closed' }
    end
    trait :archived do
      status { 'archived' }
    end
    shared_to { 'anyone' }
  end

  factory :fixed_order_intervention, class: Intervention::FixedOrder do
    user
    name { 'Intervention - Fixed Order' }
    shared_to { 'registered' }
  end

  factory :flexible_order_intervention, class: Intervention::FlexibleOrder do
    user
    name { 'Intervention - Flexible Order' }
    shared_to { 'registered' }
  end

  factory :flexible_order_intervention_with_file, class: Intervention::FlexibleOrder do
    user
    name { 'Intervention - Flexible Order' }
    shared_to { 'registered' }
    files { [FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg')] }
  end
end
