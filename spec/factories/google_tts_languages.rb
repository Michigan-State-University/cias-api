# frozen_string_literal: true

FactoryBot.define do
  factory :google_tts_language do
    language_name { 'English (United States)' }
  end

  trait :with_voices do
    after(:create) do |language|
      3.times do
        language.google_tts_voices << create(:google_tts_voice)
      end
    end
  end
end
