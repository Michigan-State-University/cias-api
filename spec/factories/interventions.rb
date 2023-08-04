# frozen_string_literal: true

FactoryBot.define do
  factory :intervention do
    user
    name { 'Intervention' }
    license_type { 'unlimited' }
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

    trait :cleared do
      cleared { true }
    end

    trait :with_navigator_setup do
      after(:build) do |intervention|
        intervention.live_chat_enabled = true
      end
    end

    trait :with_navigators do
      after(:build) do |intervention|
        intervention.navigators << create(:user, :confirmed, :navigator)
      end
    end

    trait :with_collaborators do
      after(:build) do |intervention|
        intervention.collaborators << create(:collaborator, user: create(:user, :researcher, :confirmed))
      end
    end

    trait :with_collaborators_with_data_access do
      after(:build) do |intervention|
        intervention.collaborators << create(:collaborator, user: create(:user, :researcher, :confirmed), edit: true, view: true, data_access: true)
      end
    end

    trait :with_short_link do
      after(:create) do |intervention|
        intervention.update(short_links: [create(:short_link, linkable: intervention)])
      end
    end

    trait :with_navigator_setup_and_phone do
      after(:build) do |intervention|
        intervention.live_chat_enabled = true
      end

      after(:create) do |intervention|
        intervention.navigator_setup.update!(phone: Phone.new(number: '111111111', prefix: '+48', iso: 'PL', communication_way: 'call'))
      end
    end

    trait :with_navigator_setup_and_message_phone do
      after(:build) do |intervention|
        intervention.live_chat_enabled = true
      end

      after(:create) do |intervention|
        intervention.navigator_setup.update!(message_phone: Phone.new(number: '222222222', prefix: '+48', iso: 'PL', communication_way: 'message'))
      end
    end
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
