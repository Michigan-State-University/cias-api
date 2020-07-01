# frozen_string_literal: true

class Question::Narrator
  attr_accessor :question, :speech_scope, :outdated_files

  def initialize(question)
    @question = question
    @outdated_files = []
  end

  def execute
    return unless create_speech?
    return unless question.narrator_changed?

    extract_speech_scope
    blocks_processing
    delete_outdated_files
  end

  private

  def create_speech?
    question.narrator['settings']['voice']
  end

  def extract_speech_scope
    self.speech_scope = 'from_question'
    question.narrator['blocks'].each do |block|
      next unless block.value?('Speech')

      self.speech_scope = 'blocks'
      break
    end
  end

  def blocks_sha256_digest(extend = nil)
    question.public_send("narrator#{extend}")[speech_scope].each do |block|
      next unless block['type'].eql?('Speech')

      block['text'].each_with_index do |text, index|
        block['sha256'][index] = Digest::SHA256.hexdigest(text)
      end
    end
  end

  def blocks_collection
    @blocks_collection ||= blocks_sha256_digest
  end

  def was_blocks_collection
    @was_blocks_collection ||= blocks_sha256_digest(:_was)
  end

  def was_block(index)
    was_blocks_collection[index]
  end

  def was_sha256(index_processing)
    was_block(index_processing)['sha256']
  end

  def was_audio_url(index_processing, index)
    return nil if index.nil?

    was_block(index_processing)['audio_urls'][index]
  end

  def url_to_filename(url)
    url&.split('/')&.last
  end

  def harvest_outdated_files(index_processing)
    urls = was_block(index_processing)['audio_urls']
    return if urls.empty?

    outdated_files.concat(urls.map { |url| url_to_filename(url) }.compact)
  end

  def delete_outdated_files
    CleanJob::Blobs.perform_later(outdated_files)
  end

  def processing(block, index_processing)
    harvest_outdated_files(index_processing)
    block['sha256'].each_with_index do |digest, index_block|
      was_at_index = was_sha256(index_processing).index(digest)
      was_audio_url_result = was_audio_url(index_processing, was_at_index)
      new_audio_url = if was_at_index.nil? || was_audio_url_result.nil?
                        Speech.new(
                          question,
                          speech_scope: speech_scope,
                          index_processing: index_processing,
                          index_block: index_block
                        ).execute
                      else
                        was_audio_url_result
                      end
      question.narrator[speech_scope][index_processing]['audio_urls'][index_block] = new_audio_url
      outdated_files.delete(url_to_filename(new_audio_url))
    end
  end

  def blocks_processing
    blocks_collection.each_with_index { |block, index| processing(block, index) }
  end
end
