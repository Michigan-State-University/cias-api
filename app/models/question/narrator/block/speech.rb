# frozen_string_literal: true

class Question::Narrator::Block::Speech < Question::Narrator::Block
  def build
    replace_urls

    block
  end

  private

  def replace_urls
    block['audio_urls'] = block['text'].map.with_index(0) do |text, index_block|
      audio = V1::AudioService.new(text).execute
      block['sha256'][index_block] = audio.sha256
      audio.url
    end
  end
end
