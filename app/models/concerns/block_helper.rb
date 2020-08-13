# frozen_string_literal: true

module BlockHelper
  def speech?(block)
    block['type'].eql?('Speech')
  end

  def reflection?(block)
    block['type'].eql?('Reflection')
  end
end
