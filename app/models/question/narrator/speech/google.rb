# frozen_string_literal: true

class Question::Narrator::Speech::Google
  include Question::Narrator::Speech::Interface

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
    @client ||= Google::Cloud::TextToSpeech.text_to_speech
  end
end
