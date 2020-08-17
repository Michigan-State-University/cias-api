# frozen_string_literal: true

module BlockHelper
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
