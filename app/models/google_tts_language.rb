# frozen_string_literal: true

class GoogleTtsLanguage < ApplicationRecord
  has_many :google_tts_voices

  default_scope { order(:language_name) }
end
