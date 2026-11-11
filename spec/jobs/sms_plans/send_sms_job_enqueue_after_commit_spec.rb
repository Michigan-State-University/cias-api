# frozen_string_literal: true

require 'rails_helper'

# Regression guard for the SMS webhook reply path (CIAS30-4189, audit item 10):
# SmsPlans::SendSmsJob must enqueue only after the surrounding DB transaction commits,
# so a rollback (or a Twilio webhook redelivery after one) cannot send a duplicate SMS.
# Real commits/rollbacks are needed for enqueue-after-commit to fire, hence no transactional fixtures.
RSpec.describe SmsPlans::SendSmsJob, type: :job do
  self.use_transactional_tests = false

  before do
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end

  describe 'enqueue is tied to the surrounding transaction commit' do
    it 'does not send the SMS when the surrounding transaction rolls back' do
      ActiveRecord::Base.transaction do
        described_class.perform_later('+12015550123', 'hello', nil, nil)
        raise ActiveRecord::Rollback
      end

      expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to be_empty
    end

    it 'sends the SMS exactly once when the surrounding transaction commits' do
      ActiveRecord::Base.transaction do
        described_class.perform_later('+12015550123', 'hello', nil, nil)
      end

      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)
    end
  end
end
