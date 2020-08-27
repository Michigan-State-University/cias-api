# frozen_string_literal: true

class Audio::TextToSpeech < SimpleDelegator
  attr_accessor :mp3_file
  attr_reader :text

  def initialize(audio, text:)
    @text = text
    super(audio)
  end

  def execute
    MetaOperations::FilesKeeper.new(
      stream: fetch_speech_from_text, add_to: self,
      filename: sha256, macro: :mp3, ext: :mp3, type: 'audio/mpeg'
    ).execute
    url
  end

  private

  def require_provider
    @require_provider ||= ENV.fetch('TEXT_TO_SPEECH_PROVIDER', 'Google')
  end

  def provider
    @provider ||= begin
      "Audio::TextToSpeech::#{require_provider.classify}".safe_constantize
    end
  end

  def fetch_speech_from_text
    provider.new(text).synthesize
  end
end
