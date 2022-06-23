# frozen_string_literal: true

class LiveChat::MessageTooLongException < StandardError
  def initialize(msg, channel_id, conversation_id)
    super(msg)
    @channel_id = channel_id
    @conversation_id = conversation_id
  end

  attr_reader :channel_id, :conversation_id
end
