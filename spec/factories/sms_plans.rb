# frozen_string_literal: true

FactoryBot.define do
  factory :sms_plan do
    association(:session)
    sequence(:name) { |s| "sms_plan#{s}" }
    schedule { SmsPlan.schedules[:after_session_end] }
    frequency { SmsPlan.frequencies[:once] }
  end
end
