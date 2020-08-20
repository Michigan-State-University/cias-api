# frozen_string_literal: true

module BlockHelper
  VOICE_BLOCKS = %w[Speech ReadQuestion Reflection].freeze
  ANIMATION_BLOCKS = %w[BodyAnimation HeadAnimation].freeze

  def voice_block?(block)
    VOICE_BLOCKS.include?(block['type'])
  end

  def animation_block?(block)
    ANIMATION_BLOCKS.include?(block['type'])
  end

  def speech?(block)
    block['type'].eql?('Speech')
  end

  def read_question?(block)
    block['type'].eql?('ReadQuestion')
  end

  def reflection?(block)
    block['type'].eql?('Reflection')
  end
end
