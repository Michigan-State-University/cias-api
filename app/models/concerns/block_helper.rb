# frozen_string_literal: true

module BlockHelper
  VOICE_BLOCKS = %w[ReadQuestion Reflection ReflectionFormula Speech].freeze
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

  def reflection_formula?(block)
    block['type'].eql?('ReflectionFormula')
  end
end
