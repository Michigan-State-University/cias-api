# frozen_string_literal: true

class V1::GoogleTtsLanguagesVoicesService
  attr_reader :google_tts_languages

  def initialize
    @google_tts_languages = GoogleTtsLanguage.includes(:google_tts_voices)
  end

  def google_tts_voices(google_tts_language_id)
    google_tts_languages.find(google_tts_language_id).google_tts_voices
  end
end
