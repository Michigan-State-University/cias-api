# frozen_string_literal: true

module TwilioWebhookSignature
  extend ActiveSupport::Concern

  included do
    prepend_before_action :verify_twilio_signature
  end

  private

  def verify_twilio_signature
    head :forbidden unless twilio_signature_valid?
  end

  def twilio_signature_valid?
    auth_token = ENV.fetch('TWILIO_AUTH_TOKEN', nil)
    signature = request.headers['X-Twilio-Signature']
    return false if auth_token.blank? || signature.blank?

    Twilio::Security::RequestValidator.new(auth_token).validate(request.original_url, request.POST, signature)
  end
end
