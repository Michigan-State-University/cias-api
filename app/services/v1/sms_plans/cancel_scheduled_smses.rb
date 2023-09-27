# frozen_string_literal: true

class V1::SmsPlans::CancelScheduledSmses
  def self.call(intervention_id)
    new(intervention_id).call
  end

  def initialize(intervention_id)
    @intervention_id = intervention_id
  end

  def call
    queue = Sidekiq::ScheduledSet.new
    queue.scan('SmsPlans::SendSmsJob').each do |job|
      job.delete if job.args.first['arguments'][5]&.in?(session_ids)
    end
  end

  attr_reader :intervention_id

  def session_ids
    @session_ids ||= Session.where(intervention_id: intervention_id).pluck(:id)
  end
end
