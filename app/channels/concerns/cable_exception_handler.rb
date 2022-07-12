# frozen_string_literal: true

module CableExceptionHandler
  extend ActiveSupport::Concern

  included do
    rescue_from LiveChat::OperationInvalidException do |exc|
      ActionCable.server.broadcast(exc.channel_id, format_validation_error_message(exc))
    end
  end

  protected

  def format_validation_error_message(exc)
    {
      data: {
        error: exc.message,
        conversationId: exc.conversation_id
      },
      status: 422,
      topic: 'message_error'
    }
  end
end
