# frozen_string_literal: true

class V1::CatMh::LanguageSerializer < V1Serializer
  attributes :id, :language_id, :name
  has_many :google_tts_voices, through: :cat_mh_google_tts_voices, serializer: V1::VoiceSerializer
end
