# frozen_string_literal: true

class GoogleTtsVoice < ApplicationRecord
  has_paper_trail
  belongs_to :google_tts_language

  default_scope { order(:voice_label) }
  has_many :sessions, dependent: :nullify
end
