# frozen_string_literal: true

class Communication::Sms
  HTTP_TIMEOUT = 15
  PROVIDER_ERROR = /\ASMS sending error: ([A-Z]\w*(?:::[A-Z]\w*)*),/
  DEFAULT_ERROR_CODE = 'ProviderError'
  TWILIO_CODE_PREFIX = 'TWILIO_'
  RecipientOptedOut = Class.new(StandardError)

  attr_accessor :errors
  attr_reader :sms, :client

  def initialize(message_or_id, bypass_opt_out: false, recipient_user_ids: nil)
    @sms = message_or_id.is_a?(Message) ? message_or_id : Message.find(message_or_id)
    @bypass_opt_out = bypass_opt_out
    @recipient_user_ids = recipient_user_ids
    @client = Twilio::REST::Client.new(ENV.fetch('TWILIO_ACCOUNT_SID', nil), ENV.fetch('TWILIO_AUTH_TOKEN', nil), nil, nil,
                                       Twilio::HTTP::Client.new(timeout: HTTP_TIMEOUT))
    @errors = []
  end

  def send_message
    ensure_recipient_not_opted_out! unless @bypass_opt_out

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
    @provider_error_code = error_code_for(e)
    errors << "SMS sending error: #{e.class}, #{e.message}"
  end

  def failed?
    errors.any? || sms.status == 'error'
  end

  def provider_error_code
    return unless failed?

    @provider_error_code || errors.filter_map { |entry| entry[PROVIDER_ERROR, 1] }.first || DEFAULT_ERROR_CODE
  end

  private

  def error_code_for(error)
    return error.class.name unless error.is_a?(Twilio::REST::RestError) && error.code.present?

    "#{TWILIO_CODE_PREFIX}#{error.code}"
  end

  def ensure_recipient_not_opted_out!
    return if recipient_user_ids.empty?
    return unless ::SmsOptOut.exists?(user_id: recipient_user_ids)

    raise RecipientOptedOut, 'recipient opted out of SMS'
  end

  def recipient_user_ids
    @recipient_user_ids ||= begin
      parsed = Phonelib.parse(sms.phone)
      if parsed.valid?
        Phone.where(prefix: "+#{parsed.country_code}", number: parsed.raw_national).where.not(user_id: nil).pluck(:user_id)
      else
        []
      end
    end
  end
end
