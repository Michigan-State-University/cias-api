# frozen_string_literal: true

class Communication::Sms
  attr_accessor :errors
  attr_reader :sms, :client

  def initialize(message_id)
    @sms = Message.find(message_id)
    @client = Twilio::REST::Client.new(ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN'])
    @errors = []
  end

  def send_message
    if sms.image_url.present?
      client.messages.create(
        from: ENV['TWILIO_FROM'],
        to: sms.phone,
        body: sms.body,
        media_url: [image_url]
      )
    else
      client.messages.create(
        from: ENV['TWILIO_FROM'],
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
