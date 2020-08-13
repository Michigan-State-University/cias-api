# frozen_string_literal: true

class Question::Narrator::Block::Speech < Question::Narrator::Block::Interface
  def build
    prepare_sha256_for(block)
    prepare_old_block
    replace_urls

    block
  end

  private

  def prepare_sha256_for(block)
    block['sha256'] = block['text'].map do |text|
      Digest::SHA256.hexdigest(text)
    end
  end

  def prepare_old_block
    prepare_sha256_for(old_block) if old_block
  end

  def replace_urls
    block['audio_urls'] = block['sha256'].map.with_index(0) do |digest, index_block|
      was_audio_url_result = was_audio_url(digest)
      new_audio_url = was_audio_url_result || create_audio_url(digest, index_block, block)

      outdated_files.remove(new_audio_url)
      new_audio_url
    end
  end

  def was_audio_url(digest)
    was_at_index = old_block&.fetch('sha256', [])&.index(digest)
    return nil unless was_at_index

    old_block['audio_urls'][was_at_index]
  end

  def create_audio_url(digest, index_block, context)
    Question::Narrator::TextToSpeech.new(
      question,
      sha256: digest,
      text: context['text'][index_block]
    ).execute
  end
end
