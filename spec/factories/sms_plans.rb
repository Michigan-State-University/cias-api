# frozen_string_literal: true

FactoryBot.define do
  factory :sms_plan do
    association(:session)
    sequence(:name) { |s| "sms_plan#{s}" }
    no_formula_text { 'Example text' }
    schedule { SmsPlan.schedules[:after_session_end] }
    frequency { SmsPlan.frequencies[:once] }
  end
end
