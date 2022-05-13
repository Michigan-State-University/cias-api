# frozen_string_literal: true

namespace :cat_mh do
  desc 'Sets up relationships between CatMhLanguage and GoogleTtsVoice languages'

  task setup_language_voice_relationships: :environment do
    english_language = CatMhLanguage.find_by(name: 'English')
    spanish_language = CatMhLanguage.find_by(name: 'Spanish')
    chinese_traditional_language = CatMhLanguage.find_by(name: 'Chinese - simplified')
    chinese_simplified_language = CatMhLanguage.find_by(name: 'Chinese - traditional')

    english_voices = GoogleTtsVoice.joins(:google_tts_language).where('language_name LIKE ?', "#{english_language.name}%")
    spanish_voices = GoogleTtsVoice.joins(:google_tts_language).where('language_name LIKE ?', "#{spanish_language.name}%")
    chinese_voices = GoogleTtsVoice.joins(:google_tts_language).where('language_name LIKE ?', 'Chinese%')
    english_language.update!(google_tts_voices: english_voices)
    spanish_language.update!(google_tts_voices: spanish_voices)
    chinese_traditional_language.update!(google_tts_voices: chinese_voices)
    chinese_simplified_language.update!(google_tts_voices: chinese_voices)
  end
end
