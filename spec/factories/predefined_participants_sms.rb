# frozen_string_literal: true

FactoryBot.define do
  factory :pdp_sms_campaign, class: 'PredefinedParticipants::SmsCampaign' do
    association :intervention, factory: %i[intervention published]
    kind { 'invitation' }
    body { 'CIAS_TDD_CANARY_BODY' }
    scheduled_at { Time.zone.parse('2026-10-29 12:00:00') }

    trait :scheduled do
      status { 'scheduled' }
      scheduled_at { Time.current }
    end

    trait :due_soon do
      status { 'scheduled' }
      scheduled_at { 1.hour.from_now }
    end
  end

  factory :pdp_sms_delivery, class: 'PredefinedParticipants::SmsDelivery' do
    association :campaign, factory: :pdp_sms_campaign
    association :predefined_user_parameter
    body { 'CIAS_TDD_CANARY_BODY' }
  end

  factory :pdp_campaign_sms_link, class: 'SmsLink' do
    association :campaign, factory: :pdp_sms_campaign
    url { 'https://example.test/canary-target' }
    variable { 'canary_link' }
    link_type { 'website' }
  end

  factory :pdp_sms_opt_out, class: 'SmsOptOut' do
    association :user
    opted_out_at { Time.zone.parse('2026-10-29 12:00:00') }
  end
end
