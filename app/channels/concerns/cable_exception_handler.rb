# frozen_string_literal: true

module CableExceptionHandler
  extend ActiveSupport::Concern
  include MessageHandler

  included do
    rescue_from LiveChat::OperationInvalidException do |exc|
      ActionCable.server.broadcast(exc.channel_id, format_error_message(exc, 422, 'message_error', conversationId: exc.conversation_id))
    end

    rescue_from LiveChat::NavigatorUnavailableException do |exc|
      ActionCable.server.broadcast(exc.channel_id, format_error_message(exc, 404, 'navigator_unavailable_error'))
    end
  end
end
