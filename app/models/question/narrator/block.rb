# frozen_string_literal: true

class Question::Narrator::Block < SimpleDelegator
  include BlockHelper

  attr_accessor :block
  attr_reader :index_processing

  def initialize(narrator, index_processing, block)
    @index_processing = index_processing
    @block = block
    super(narrator)
  end

  def self.swap_name_into_block(block, mp3url, name_text)
    block['text'].each_with_index do |text, index|
      next text unless text == ':name:.'

      block['text'][index] = name_text
      block['audio_urls'][index] = mp3url
    end
    block
  end

  def build
    raise NotImplementedError, "subclass did not define #{__method__}"
  end

  def swap_name(_block, _mp3url, _name_text); end
end
