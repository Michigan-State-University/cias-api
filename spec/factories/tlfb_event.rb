# frozen_string_literal: true

FactoryBot.define do
  factory :tlfb_event, class: Tlfb::Event do
    name { 'event' }
    association :day
  end
end
