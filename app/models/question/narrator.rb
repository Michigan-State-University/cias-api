# frozen_string_literal: true

class Question::Narrator
  attr_accessor :question, :outdated_files, :speech_source

  def initialize(question)
    @question = question
  end

  def execute
    self.outdated_files = Blobs.new(question.narrator_was).execute

    return unless Launch.new(question, outdated_files).execute

    self.question = Standarize.new(question).execute
    self.speech_source = SpeechSource.new(question.narrator).execute
    blocks_processing
    outdated_files.purification
    question.save!
  end

  private

  def speech?(block)
    block['type'].eql?('Speech')
  end

  def blocks_sha256_digest(extend = nil)
    question.public_send("narrator#{extend}")[speech_source].each do |block|
      next unless speech?(block)

      block['sha256'] = block['text'].map do |text|
        Digest::SHA256.hexdigest(text)
      end
    end
  end

  def blocks_collection
    @blocks_collection ||= blocks_sha256_digest
  end

  def was_blocks_collection
    @was_blocks_collection ||= blocks_sha256_digest(:_was)
  end

  def was_sha256(index_processing)
    was_blocks_collection[index_processing]&.fetch('sha256', [])
  end

  def was_audio_url(index_processing, index)
    return nil if index.nil?

    was_blocks_collection[index_processing]['audio_urls'][index]
  end

  def processing(block, index_processing)
    new_audio_urls = block['sha256'].map.with_index(0) do |digest, index_block|
      if was_blocks_collection.present?
        was_at_index = was_sha256(index_processing)&.index(digest)
        was_audio_url_result = was_audio_url(index_processing, was_at_index)
      end
      new_audio_url = if was_at_index.nil? || was_audio_url_result.nil?
                        TextToSpeech.new(
                          question,
                          speech_source: speech_source,
                          index_processing: index_processing,
                          index_block: index_block
                        ).execute
                      else
                        was_audio_url_result
                      end

      outdated_files.remove(new_audio_url)
      new_audio_url
    end
    question.narrator[speech_source][index_processing]['audio_urls'] = new_audio_urls
  end

  def blocks_processing
    blocks_collection.each_with_index { |block, index| processing(block, index) if speech?(block) }
  end
end
