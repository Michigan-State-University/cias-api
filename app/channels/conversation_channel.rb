# frozen_string_literal: true

class ConversationChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'conversation_channel'
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    stop_all_streams
  end

  def on_message(data)
    # format will be for example: { 'action' => 'on_message', 'content' => 'this is the content of the message' }
    ActionCable.server.broadcast('conversation_channel', data)  # let's leave it as a broadcast for now
  end
end
