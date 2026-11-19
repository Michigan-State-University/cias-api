# frozen_string_literal: true

class V1::TwilloMessageController < V1Controller
  include TwilioWebhookSignature

  skip_before_action :authenticate_user!
  around_action :claim_message_sid, only: :create

  def create
    render xml: V1::Sms::Replay.call(from, to, body)
  end

  private

  def claim_message_sid
    return yield if message_sid.blank?

    ApplicationRecord.transaction do
      next render xml: Twilio::TwiML::MessagingResponse.new unless SmsInboundReceipt.claim(message_sid)

      yield
    end
  end

  def transformed_params
    @transformed_params ||= params.deep_transform_keys(&:underscore)
  end

  def message_sid
    transformed_params[:message_sid]
  end

  def from
    transformed_params[:from]
  end

  def to
    transformed_params[:to]
  end

  def body
    transformed_params[:body]
  end
end
