# frozen_string_literal: true

class Question::Narrator::Block::Speech < Question::Narrator::Block
  def build
    replace_urls

    block
  end

  private

  def replace_urls
    block['audio_urls'] = block['text'].map.with_index(0) do |text, index_block|
      audio = V1::AudioService.new(text, language_code: question.session.google_tts_voice.language_code, voice_type: question.session.google_tts_voice.voice_type).execute
      block['sha256'][index_block] = audio.sha256
      generate_url(audio, text)
    end
  end

  def generate_url(audio, text)
    audio.url
  rescue ActionController::UrlGenerationError => e
    audio.destroy
    audio = V1::AudioService.new(text, language_code: question.session.google_tts_voice.language_code, voice_type: question.session.google_tts_voice.voice_type).execute
    audio.url
  end
end
