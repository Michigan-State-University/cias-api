# frozen_string_literal: true

class V1::AudioService
  def create(text)
    digest = Digest::SHA256.hexdigest(text)
    audio_url = was_audio_url(digest)
    if audio_url.nil?
      audio = Audio.create!(sha256: digest)
      Audio::TextToSpeech.new(
        audio,
        text: text
      ).execute
      audio_url = audio.reload.url
    end
    audio_url
  end

  def was_audio_url(digest)
    Audio.find_by(sha256: digest)&.url
  end
end
