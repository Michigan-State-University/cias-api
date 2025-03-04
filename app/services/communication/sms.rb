# frozen_string_literal: true

class Communication::Sms
  attr_accessor :errors
  attr_reader :sms, :client

  def initialize(message_id)
    @sms = Message.find(message_id)
    @client = Twilio::REST::Client.new(ENV.fetch('TWILIO_ACCOUNT_SID', nil), ENV.fetch('TWILIO_AUTH_TOKEN', nil))
    @errors = []
  end

  def send_message
    if sms.attachment_url.present?
      client.messages.create(
        from: ENV.fetch('TWILIO_FROM', nil),
        to: sms.phone,
        body: sms.body,
        media_url: [sms.attachment_url]
      )
    else
      client.messages.create(
        from: ENV.fetch('TWILIO_FROM', nil),
        to: sms.phone,
        body: sms.body
      )
    end

    sms.update(status: 'success')
  rescue StandardError => e
    sms.update(status: 'error')
    errors << "SMS sending error: #{e.class}, #{e.message}"
  end
end
