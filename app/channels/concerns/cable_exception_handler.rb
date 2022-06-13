# frozen_string_literal: true

module CableExceptionHandler
  extend ActiveSupport::Concern

  included do
    rescue_from LiveChat::MessageTooLongException do |exc|
      ActionCable.server.broadcast(exc.conversation_channel_id, { data: { error: exc.message }, status: 422, topic: 'message-error' })
    end
  end
end
