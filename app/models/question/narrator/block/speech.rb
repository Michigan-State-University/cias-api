# frozen_string_literal: true

class Question::Narrator::Block::Speech < Question::Narrator::Block
  def build
    prepare_sha256_for(block)
    replace_urls

    block
  end

  private

  def prepare_sha256_for(block)
    block['sha256'] = block['text'].map do |text|
      Digest::SHA256.hexdigest(text.strip.downcase)
    end
  end

  def replace_urls
    block['audio_urls'] = block['sha256'].map.with_index(0) do |digest, index_block|
      was_audio_url_result = was_audio_url(digest)
      new_audio_url = was_audio_url_result || create_audio_url(digest, index_block, block)

      new_audio_url
    end
  end

  def was_audio_url(digest)
    audio = Audio.find_by(sha256: digest)
    return nil unless audio

    not_removed = outdated_files.remove(digest)
    audio.increment!(:usage_counter) if not_removed
    audio.url
  end

  def create_audio_url(digest, index_block, context)
    audio = Audio.create!(sha256: digest)
    Audio::TextToSpeech.new(
      audio,
      text: context['text'][index_block]
    ).execute
  end
end
