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
    ids.compact!
    self
  end

  def remove(digest)
    digest_index = ids.index(digest)
    ids.delete_at(digest_index) if digest_index
  end

  def purification
    counts = ids.tally
    Audio.where(sha256: ids).find_each { |audio| audio.decrement!(:usage_counter, counts[audio.sha256]) }
  end

  private

  def body(block)
    ids.concat(block['sha256'])
  end

  def blocks
    narrator['blocks'].each do |b|
      if speech?(b) || read_question?(b)
        body(b)
      elsif reflection?(b)
        reflection_block(b)
      end
    end
  end

  def reflection_block(block)
    block['reflections'].each { |ref| body(ref) }
  end
end
