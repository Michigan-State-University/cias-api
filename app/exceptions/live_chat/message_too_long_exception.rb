# frozen_string_literal: true

class LiveChat::MessageTooLongException < StandardError
  def initialize(msg, conversation_channel_id)
    super(msg)
    @conversation_channel_id = conversation_channel_id
  end

  attr_reader :conversation_channel_id
end
