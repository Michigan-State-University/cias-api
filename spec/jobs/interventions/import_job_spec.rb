# frozen_string_literal: true

RSpec.describe Interventions::ImportJob, type: :job do
  subject { described_class.perform_later(user_id, JSON.parse(invalid_json_file).deep_transform_keys(&:to_sym)) }

  let!(:user) { create(:user, :confirmed, :researcher) }
  let!(:user_id) { user.id }
  let!(:invalid_json_file) do
    File.read('spec/factories/json/invalid_intervention.json')
  end

  context 'with invalid intervention_hash' do
    before do
      ActiveJob::Base.queue_adapter = :test
    end

    it 'do not create intervention' do
      expect { subject }.not_to change(Intervention, :count)
    end
  end

  context 'when the job raises an error' do
    before do
      ActiveJob::Base.queue_adapter = :test
    end

    it 'is not retried' do
      pending 'BUG: sidekiq_options retry: false is ignored, ApplicationJob retry_on StandardError re-enqueues the job'
      expect { described_class.perform_now(user_id, SecureRandom.uuid) }.to raise_error(StandardError)
      expect(described_class).not_to have_been_enqueued
    end
  end
end
