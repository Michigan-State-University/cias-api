# frozen_string_literal: true

class Question::Narrator::Block::Speech < Question::Narrator::Block
  def build
    replace_urls

    block
  end

  private

  def replace_urls
    return unless question.session.google_tts_voice

    block['audio_urls'] = block['text'].map.with_index(0) do |text, index_block|
      audio = V1::AudioService.call(text,
                                    language_code: question.session.google_tts_voice.language_code,
                                    voice_type: question.session.google_tts_voice.voice_type)
      block['sha256'][index_block] = audio.sha256
      audio.url
    end
  end
end
