# frozen_string_literal: true

class Audio::TextToSpeech::Google
  include Audio::TextToSpeech::Interface

  attr_reader :text, :voice_type, :language

  def initialize(text, language, voice_type)
    @text = text
    @language = language || ENV.fetch('TEXT_TO_SPEECH_LANGUAGE', 'en-US')
    @voice_type = voice_type || ENV.fetch('TEXT_TO_SPEECH_VOICE', 'en-US-Standard-C')
  end

  def synthesize
    client.synthesize_speech(
      input: { text: text },
      voice: voice,
      audio_config: audio_config
    ).audio_content
  end

  private

  def voice
    @voice ||= {
      language_code: language,
      name: voice_type
    }
  end

  def audio_config
    @audio_config ||= { audio_encoding: 'MP3' }
  end

  def client
    @client ||= Google::Cloud::TextToSpeech.text_to_speech do |tts|
      tts.credentials = credentials
    end
  end

  def credentials
    @credentials ||= begin
      if Rails.env.development?
        Oj.load_file(ENV['GOOGLE_APPLICATION_CREDENTIALS'])
      else
        Oj.load(ENV['GOOGLE_APPLICATION_CREDENTIALS'])
      end
    rescue Oj::ParseError
      ENV['GOOGLE_APPLICATION_CREDENTIALS']
    end
  end
end
