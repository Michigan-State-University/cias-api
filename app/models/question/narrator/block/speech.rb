# frozen_string_literal: true

class Question::Narrator::Block::Speech < Question::Narrator::Block
  def build
    replace_urls

    block
  end

  def self.swap_name(block, mp3url, name_text)
    return block unless block['text'].include?(':name:.')

    swap_name_into_block(block, mp3url, name_text)
  end

  private

  def replace_urls
    return unless question.session.google_tts_voice

    block['text'] ||= ['']
    block['sha256'] ||= ['']

    block['audio_urls'] = block['text'].map.with_index(0) do |text, index_block|
      audio = V1::AudioService.call(text,
                                    language_code: question.session.google_tts_voice.language_code,
                                    voice_type: question.session.google_tts_voice.voice_type)
      next if audio.nil?

      block['sha256'][index_block] = audio.sha256 if block['sha256'].present?
      generate_url(audio, text)
    end
  end

  def generate_url(audio, text)
    audio.url
  rescue ActionController::UrlGenerationError
    audio.destroy
    audio = V1::AudioService.call(text, language_code: question.session.google_tts_voice.language_code,
                                        voice_type: question.session.google_tts_voice.voice_type)
    audio.url
  end
end
