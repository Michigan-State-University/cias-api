# frozen_string_literal: true

class Audio::TextToSpeech < SimpleDelegator
  attr_accessor :mp3_file
  attr_reader :text

  def initialize(audio, text:)
    @text = text
    super(audio)
  end

  def execute
    mp3_create
    mp3_upload
    mp3_remove_file
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

  def mp3_filename
    @mp3_filename ||= "#{sha256}.mp3"
  end

  def mp3_create
    self.mp3_file = File.open(Rails.root.join('tmp', mp3_filename), 'wb') do |file|
      file.write(fetch_speech_from_text)
      file.path
    end
  end

  def mp3_upload
    mp3.attach(
      io: File.open(mp3_file),
      filename: mp3_filename,
      content_type: 'audio/mpeg'
    )
    save!
  end

  def mp3_remove_file
    File.delete(mp3_create) if File.exist?(mp3_create)
  end
end
