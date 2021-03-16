# frozen_string_literal: true

class V1::AudioService
  def create(text, preview: false)
    digest = Digest::SHA256.hexdigest(text)
    audio = Audio.find_by(sha256: digest)
    if audio.nil?
      audio = Audio.create!(sha256: digest)
      Audio::TextToSpeech.new(
        audio,
        text: text
      ).execute
      audio.usage_counter = 0 if preview
    else
      audio.increment!(:usage_counter) unless preview
    end
    audio.save
    audio.reload
  end
end
