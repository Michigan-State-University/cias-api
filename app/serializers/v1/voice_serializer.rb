# frozen_string_literal: true

class V1::VoiceSerializer < V1Serializer
  attributes :google_tts_language_id, :voice_label, :voice_type, :language_code
end
