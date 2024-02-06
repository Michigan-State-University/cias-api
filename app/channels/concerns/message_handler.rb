# frozen_string_literal: true

module MessageHandler
  extend ActiveSupport::Concern

  protected

  def format_error_message(exc, status, topic, additional_error_data)
    {
      data: {
        error: exc.message,
        **additional_error_data
      },
      status: status,
      topic: topic
    }
  end

  def generic_message(payload, topic, status = 200)
    {
      data: payload,
      topic: topic,
      status: status
    }
  end
end
