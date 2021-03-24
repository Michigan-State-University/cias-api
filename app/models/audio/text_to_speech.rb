# frozen_string_literal: true

class Audio::TextToSpeech < SimpleDelegator
  attr_accessor :mp3_file
  attr_reader :text, :language, :voice_type

  def initialize(audio, text:, language:, voice_type:)
    @text = text
    @language = language
    @voice_type = voice_type
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
    provider.new(text, language, voice_type).synthesize
  end
end
