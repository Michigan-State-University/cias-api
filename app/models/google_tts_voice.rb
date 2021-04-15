# frozen_string_literal: true

class GoogleTtsVoice < ApplicationRecord
  belongs_to :google_tts_language

  default_scope { order(:voice_label) }
end
