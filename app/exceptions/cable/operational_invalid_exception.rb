# frozen_string_literal: true

class Cable::OperationalInvalidException < StandardError
  def initialize(msg, channel_id)
    super(msg)
    @channel_id = channel_id
  end

  attr_reader :channel_id
end
