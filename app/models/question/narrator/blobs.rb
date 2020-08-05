# frozen_string_literal: true

class Question::Narrator::Blobs
  attr_accessor :ids
  attr_reader :narrator

  def initialize(narrator)
    @narrator = narrator
    @ids = []
  end

  def execute
    blocks
    from_question
    ids.compact!
    self
  end

  def remove(audio_url)
    ids.delete(split_url(audio_url))
  end

  def purification
    ::CleanJob::Blobs.perform_later(ids)
  end

  private

  def split_url(url)
    url.split('/').last
  end

  def extract_filenames(block)
    block.map { |i| split_url(i) }
  end

  def body(block)
    ids.concat(extract_filenames(block['audio_urls']))
  end

  def blocks
    narrator['blocks'].each { |b| body(b) if speech?(b) }
  end

  def from_question
    narrator['from_question'].each { |b| body(b) }
  end

  def speech?(block)
    block['type'].eql?('Speech')
  end
end
