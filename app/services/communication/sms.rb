# frozen_string_literal: true

class Communication::Sms
  attr_accessor :errors
  attr_reader :sms, :client

  TWILIO = Settings.services.twilio

  def initialize(message_id, client = Twilio::REST::Client.new(TWILIO.sid, TWILIO.token))
    @sms = Message.find message_id
    @client = client
    @errors = []
  end

  def send_message
    client.messages.create(
      from: TWILIO.from,
      to: sms.phone,
      body: sms.body
    )
    sms.update(status: 'success')
  rescue StandardError => e
    sms.update(status: 'error')
    errors << "SMS sending error: #{e.class}, #{e.message}"
  end
end
