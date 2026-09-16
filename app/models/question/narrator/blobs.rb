# frozen_string_literal: true

class Question::Narrator::Blobs
  include BlockHelper

  def self.call(narrator, cloned = false)
    new(narrator, cloned).call
  end

  attr_accessor :ids
  attr_reader :narrator, :cloned

  def initialize(narrator, cloned = false)
    @narrator = narrator
    @cloned = cloned
    @ids = []
  end

  def call
    blocks
    ids.compact!
    self
  end

  def remove?(digest)
    return true if cloned

    digest_index = ids.index(digest)
    ids.delete_at(digest_index) if digest_index
    digest_index.nil?
  end

  def purge
    return if cloned

    count_hash = {}
    count_hash.default = []
    ids.tally.each do |id, count|
      count_hash[count] += [id]
    end

    count_hash.each do |count, audio_ids|
      Audio.where(sha256: audio_ids).update_counters(usage_counter: -count)
    end
  end

  private

  def body(block)
    return if block['sha256'].blank?

    ids.concat(block['sha256'])
  end

  def blocks
    narrator['blocks'].each do |b|
      if speech?(b) || read_question?(b)
        body(b)
      elsif reflection?(b) || reflection_formula?(b)
        reflection_block(b)
      end
    end
  end

  def reflection_block(block)
    block['reflections'].each { |ref| body(ref) }
  end
end
