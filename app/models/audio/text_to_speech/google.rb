# frozen_string_literal: true

class Audio::TextToSpeech::Google
  include Audio::TextToSpeech::Interface

  LINEAR16_VOICE_TYPES = %w[en-US-Journey-D en-US-Journey-F en-US-Journey-O].freeze

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
    @audio_config ||= { audio_encoding: get_proper_encoding(voice_type) }
  end

  def client
    @client ||= Google::Cloud::TextToSpeech.text_to_speech do |tts|
      tts.credentials = credentials
    end
  end

  def credentials
    @credentials ||= begin
      if Rails.env.development?
        Oj.load_file(ENV.fetch('GOOGLE_APPLICATION_CREDENTIALS', nil))
      else
        Oj.load(ENV.fetch('GOOGLE_APPLICATION_CREDENTIALS', nil))
      end
    rescue Oj::ParseError
      ENV.fetch('GOOGLE_APPLICATION_CREDENTIALS', nil)
    end
  end

  def get_proper_encoding(voice_type)
    case voice_type
    when ->(type) { LINEAR16_VOICE_TYPES.include?(type) } then 'LINEAR16'
    else
      'MP3'
    end
  end
end
