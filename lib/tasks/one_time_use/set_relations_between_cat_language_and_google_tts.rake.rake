# frozen_string_literal: true

namespace :cat_mh do
  desc 'Sets up relationships between AuxiliaryCatMhLanguage and AuxiliaryGoogleTtsVoice languages'

  task setup_language_voice_relationships: :environment do
    english_language = AuxiliaryCatMhLanguage.find_by(name: 'English')
    spanish_language = AuxiliaryCatMhLanguage.find_by(name: 'Spanish')
    chinese_traditional_language = AuxiliaryCatMhLanguage.find_by(name: 'Chinese - simplified')
    chinese_simplified_language = AuxiliaryCatMhLanguage.find_by(name: 'Chinese - traditional')

    english_voices = AuxiliaryGoogleTtsVoice.joins(:google_tts_language).where('language_name LIKE ?', "#{english_language.name}%")
    spanish_voices = AuxiliaryGoogleTtsVoice.joins(:google_tts_language).where('language_name LIKE ?', "#{spanish_language.name}%")
    chinese_voices = AuxiliaryGoogleTtsVoice.joins(:google_tts_language).where('language_name LIKE ?', 'Chinese%')
    english_language.update!(google_tts_voices: english_voices)
    spanish_language.update!(google_tts_voices: spanish_voices)
    chinese_traditional_language.update!(google_tts_voices: chinese_voices)
    chinese_simplified_language.update!(google_tts_voices: chinese_voices)
  end

  class AuxiliaryGoogleTtsVoice < ActiveRecord::Base
    self.table_name = 'google_tts_voices'

    belongs_to :google_tts_language, class_name: 'AuxiliaryGoogleTtsLanguage'
  end

  class AuxiliaryGoogleTtsLanguage < ActiveRecord::Base
    self.table_name = 'google_tts_languages'

    has_many :google_tts_voices, foreign_key: :google_tts_language_id, class_name: 'AuxiliaryGoogleTtsVoice'
  end

  class AuxiliaryCatMhGoogleTtsVoice < ActiveRecord::Base
    self.table_name = 'cat_mh_google_tts_voices'

    belongs_to :cat_mh_language, class_name: 'AuxiliaryCatMhLanguage', foreign_key: :cat_mh_language_id
    belongs_to :google_tts_voice, class_name: 'AuxiliaryGoogleTtsVoice', foreign_key: :google_tts_voice_id
  end

  class AuxiliaryCatMhLanguage < ActiveRecord::Base
    self.table_name = 'cat_mh_languages'

    has_many :cat_mh_google_tts_voices, dependent: :destroy, class_name: 'AuxiliaryCatMhGoogleTtsVoice', foreign_key: :cat_mh_language_id
    has_many :google_tts_voices, through: :cat_mh_google_tts_voices, dependent: :destroy, class_name: 'AuxiliaryGoogleTtsVoice', foreign_key: :cat_mh_language_id
  end
end
