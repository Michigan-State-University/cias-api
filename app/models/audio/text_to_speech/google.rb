# frozen_string_literal: true

class Audio::TextToSpeech::Google
  include Audio::TextToSpeech::Interface

  attr_reader :text

  def initialize(text)
    @text = text
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
      language_code: ENV.fetch('TEXT_TO_SPEECH_LANGUAGE', 'en-US'),
      name: ENV.fetch('TEXT_TO_SPEECH_VOICE', 'en-US-Standard-C')
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
      Oj.load(ENV['GOOGLE_APPLICATION_CREDENTIALS'])
    rescue Oj::ParseError
      ENV['GOOGLE_APPLICATION_CREDENTIALS']
    end
  end
end
