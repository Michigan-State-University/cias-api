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
    return response_message unless message.casecmp('STOP').zero?

    delete_messaged_for(from_number)
    response_message
  end

  attr_reader :from_number, :to_number, :message

  private

  def response_message
    @response_message ||= Twilio::TwiML::MessagingResponse.new
  end

  def delete_messaged_for(number)
    queue = Sidekiq::ScheduledSet.new
    queue.each do |job|
      job_args = job.args.first
      job.delete if job_args['job_class'] == 'SmsPlans::SendSmsJob' && job_args['arguments'].first.eql?(number)
    end
  end
end
