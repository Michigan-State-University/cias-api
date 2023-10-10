# frozen_string_literal: true


class V1::Sms::Replay
  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @from_number = params[:from]
    @to_number = params[:to]
    @message = params[:body].to_s
  end

  def call
    return help_message unless message.casecmp('STOP').zero?
  end

  attr_reader :from_number, :to_number, :message

  private

  def help_message
    response.message do |message|
      message.body(I18n.t('sms_replay.help'))
    end
  end

  def response
    @response ||= Twilio::TwiML::MessagingResponse.new
  end
end
