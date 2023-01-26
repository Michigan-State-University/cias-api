# frozen_string_literal: true

FactoryBot.define do
  factory :short_link do
    sequence(:name) { |s| "example_url_#{s}" }
  end
end
