# frozen_string_literal: true

class Question::Narrator::TextToSpeech < SimpleDelegator
  attr_accessor :question, :mp3_file, :audio_url
  attr_reader :sha256, :text

  def initialize(question, sha256:, text:)
    @sha256 = sha256
    @text = text
    super(question)
  end

  def execute
    mp3_create
    mp3_upload
    mp3_retrieve_url
    mp3_remove_file
    audio_url
  end

  private

  def require_provider
    @require_provider ||= ENV.fetch('TEXT_TO_SPEECH_PROVIDER', 'Google')
  end

  def provider
    @provider ||= begin
      "Question::Narrator::TextToSpeech::#{require_provider.classify}".safe_constantize
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
    speeches.attach(
      io: File.open(mp3_file),
      filename: mp3_filename,
      content_type: 'audio/mpeg'
    )
    save!
  end

  def mp3_retrieve_url
    file = speeches.blobs.find_by(filename: mp3_filename)
    self.audio_url = Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true)
  end

  def mp3_remove_file
    File.delete(mp3_create) if File.exist?(mp3_create)
  end
end
