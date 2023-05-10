# frozen_string_literal: true

FactoryBot.define do
  factory :time_range do
    from { 12 }
    to { 17 }
    default { true }
    label { :afternoon }
  end
end
