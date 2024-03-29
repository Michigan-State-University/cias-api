# frozen_string_literal: true

class V1::AudioService
  attr_reader :text, :language_code, :voice_type, :preview_audio

  def self.call(text, preview: false, language_code: nil, voice_type: nil)
    new(text, preview: preview, language_code: language_code, voice_type: voice_type).call
  end

  def initialize(text, preview: false, language_code: nil, voice_type: nil)
    @text = unify_text(text)
    @language_code = language_code || ENV.fetch('TEXT_TO_SPEECH_LANGUAGE', 'en-US')
    @voice_type = voice_type || ENV.fetch('TEXT_TO_SPEECH_VOICE', 'en-US-Standard-C')
    @preview_audio = preview
  end

  def call
    digest = prepare_audio_digest
    audio = Audio.find_by(sha256: digest)
    audio = create_audio(digest) if audio.nil?
    audio
  end

  def prepare_audio_digest
    Digest::SHA256.hexdigest("#{text}_#{language_code}_#{voice_type}")
  end

  def create_audio(digest)
    audio = nil
    Audio.transaction do
      audio = Audio.create!(sha256: digest, language: language_code, voice_type: voice_type)
      audio.usage_counter = 0 if preview_audio
      Audio::TextToSpeech.new(
        audio,
        text: text,
        language: language_code,
        voice_type: voice_type
      ).execute
      audio.save
    end
    audio.reload
  end

  def unify_text(text)
    text.tr('¿,!.', '').strip.downcase
  end
end
