# frozen_string_literal: true

require 'active_support/testing/time_helpers'

module ScheduledSmsHelpers
  FakeScheduledJob = Struct.new(:args) do
    attr_reader :deleted

    def delete
      @deleted = true
    end

    def deleted?
      @deleted == true
    end
  end

  def fake_send_sms_job_for(number)
    FakeScheduledJob.new([{ 'job_class' => 'SmsPlans::SendSmsJob', 'arguments' => [number, 'CIAS_TDD_CANARY_BODY', nil, nil, false, nil] }])
  end

  def stub_scheduled_set(jobs)
    allow(Sidekiq::ScheduledSet).to receive(:new).and_return(jobs)
  end

  def stub_sms_provider
    calls = []
    allow_any_instance_of(Communication::Sms).to receive(:send_message) do |sms|
      calls << sms
      true
    end
    calls
  end
end
