# frozen_string_literal: true

class Question::Narrator::Blobs
  include BlockHelper

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

  def extract_filenames(audio_urls)
    audio_urls.map { |url| split_url(url) }
  end

  def body(block)
    ids.concat(extract_filenames(block['audio_urls']))
  end

  def blocks
    narrator['blocks'].each do |b|
      if speech?(b)
        body(b)
      elsif reflection?(b)
        reflection_block(b)
      end
    end
  end

  def reflection_block(block)
    block['reflections'].each { |ref| body(ref) }
  end

  def from_question
    narrator['from_question'].each { |b| body(b) }
  end
end
