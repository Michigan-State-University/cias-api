# frozen_string_literal: true

class CatMhLanguage < ApplicationRecord
  has_many :cat_mh_test_type_languages, dependent: :destroy
  has_many :sessions, inverse_of: :cat_mh_language, class_name: 'Session::CatMh', dependent: :destroy
  has_many :cat_mh_google_tts_voices, dependent: :destroy
  has_many :google_tts_voices, through: :cat_mh_google_tts_voices, dependent: :destroy
end
