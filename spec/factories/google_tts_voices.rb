# frozen_string_literal: true

FactoryBot.define do
  factory :google_tts_voice do
    voice_label { 'Wavenet-male-1' }
    voice_type { 'ar-XA-Wavenet-B' }
    language_code { 'ar-XA' }
    association :google_tts_language
  end
end
