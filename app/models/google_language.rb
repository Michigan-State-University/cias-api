# frozen_string_literal: true

class GoogleLanguage < ApplicationRecord
  has_many :interventions, dependent: :nullify
  belongs_to :google_tts_language, inverse_of: :google_tts_voices, optional: true

  def default_google_tts_voice
    return google_tts_language.google_tts_voices.first if google_tts_language.present?

    first_word = language_name.split.first
    GoogleTtsLanguage.where('language_name like?', "%#{first_word}%")&.first&.google_tts_voices&.first
  end
end
