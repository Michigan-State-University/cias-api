# frozen_string_literal: true

class LiveChat::CallOutUnavailableException < StandardError
  def initialize(msg, channel_id, unlock_time)
    super(msg)
    @channel_id = channel_id
    @unlock_time = unlock_time
  end

  attr_reader :channel_id, :unlock_time
end
