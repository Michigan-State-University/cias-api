# frozen_string_literal: true

class CatMhGoogleTtsVoice < ApplicationRecord
  belongs_to :cat_mh_language
  belongs_to :google_tts_voice
end
