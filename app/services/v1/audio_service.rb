# frozen_string_literal: true

class V1::AudioService
  attr_reader :text, :language_code, :voice_type, :preview_audio

  def initialize(text, preview: false)
    @text = text
    @language_code = ENV.fetch('TEXT_TO_SPEECH_LANGUAGE', 'en-US')
    @voice_type = ENV.fetch('TEXT_TO_SPEECH_VOICE', 'en-US-Standard-C')
    @preview_audio = preview
  end

  def execute
    digest = prepare_audio_digest
    audio = Audio.find_by(sha256: digest, language: language_code, voice_type: voice_type)
    audio&.increment!(:usage_counter) unless preview_audio
    audio = create_audio(digest) if audio.nil?
    audio.save
    audio.reload
  end

  def prepare_audio_digest
    clear_text = text.tr(',!.', '').strip.downcase
    Digest::SHA256.hexdigest(clear_text)
  end

  def create_audio(digest)
    clear_text = text.tr(',!.', '').strip.downcase
    audio = Audio.create!(sha256: digest, language: language_code, voice_type: voice_type)
    audio.usage_counter = 0 if preview_audio
    Audio::TextToSpeech.new(
      audio,
      text: text,
      language: language_code,
      voice_type: voice_type
    ).execute
    audio
  end
end
