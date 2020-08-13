# frozen_string_literal: true

class Question::Narrator::Block::Interface < SimpleDelegator
  include BlockHelper

  attr_accessor :block, :old_block
  attr_reader :index_processing, :narrator

  def initialize(narrator, index_processing, block, old_block = nil)
    @index_processing = index_processing
    @block = block
    @old_block = old_block
    super(narrator)
  end

  def build
    raise NotImplementedError, "subclass did not define #{__method__}"
  end
end
