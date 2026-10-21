# frozen_string_literal: true

RSpec.describe ApplicationJob, type: :job do
  context 'when a GlobalID argument no longer exists' do
    let(:job_class) { MultipleCharacters::ChangeNarratorJob }
    let(:user) { create(:user, :confirmed, :researcher) }
    let!(:job_data) { job_class.new(user, Session.name, SecureRandom.uuid, 'peedy', {}).serialize }

    before do
      ActiveJob::Base.queue_adapter = :test
      user.destroy!
    end

    it 'discards the job instead of retrying it' do
      pending 'BUG: ActiveJob::DeserializationError is retried by ApplicationJob retry_on StandardError instead of being discarded'
      ActiveJob::Base.execute(job_data)
      expect(job_class).not_to have_been_enqueued
    end
  end
end
