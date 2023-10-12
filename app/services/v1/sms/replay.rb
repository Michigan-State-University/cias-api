# frozen_string_literal: true

class V1::Sms::Replay
  def self.call(params)
    new(params).call
  end

  def initialize(params)
    @from_number = params['from']
    @to_number = params['to']
    @message = params['body'].to_s
  end

  def call
    p '-------------IN THE SERVICE------------'
    return help_message unless message.casecmp('STOP').zero?
    p '----------------DETECTED STOP-------------'

    delete_messaged_for(from_number)
    p '-------------GENERATEING RESPONSE...------------'
    stop_message
  end

  attr_reader :from_number, :to_number, :message

  private

  def help_message
    response.message do |message|
      message.body(I18n.t('sms_replay.help'))
    end
  end

  def stop_message
    response.message do |message|
      message.body(I18n.t('sms_replay.stop'))
    end
  end

  def response
    @response ||= Twilio::TwiML::MessagingResponse.new
  end

  def delete_messaged_for(number)
    queue = Sidekiq::ScheduledSet.new
    queue.each do |job|
      job_args = job.first.args
      job.delete if job_args['job_class'] == 'SmsPlans::SendSmsJob' && job_args['arguments'].first.eql?(number)
    end
  end
end
