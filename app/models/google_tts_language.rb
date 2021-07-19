# frozen_string_literal: true

class GoogleTtsLanguage < ApplicationRecord
  has_paper_trail
  has_many :google_tts_voices, dependent: :destroy

  default_scope { order(:language_name) }
end
