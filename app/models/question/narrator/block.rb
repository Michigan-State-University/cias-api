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

  def build
    raise NotImplementedError, "subclass did not define #{__method__}"
  end
end
