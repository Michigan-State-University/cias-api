# frozen_string_literal: true

RSpec.describe ChartRegenerationLockManagement, type: :job do
  let(:organization) { create(:organization) }
  let(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let(:dashboard_section) { create(:dashboard_section, reporting_dashboard: reporting_dashboard) }
  let(:chart) { create(:chart, dashboard_section: dashboard_section, regenerating_since: 2.hours.ago) }

  # The shape Sidekiq hands the death handler for an ActiveJob: the payload is nested under
  # 'args', and 'class' is the wrapper rather than the job.
  def sidekiq_message_for(job)
    {
      'class' => 'ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper',
      'wrapped' => job.class.name,
      'queue' => 'default',
      'args' => [job.serialize]
    }
  end

  def fire_retries_exhausted(job)
    handler = RegenerateChartsJob.sidekiq_retries_exhausted_block
    handler.call(sidekiq_message_for(job), StandardError.new('boom'))
  end

  describe 'sidekiq_retries_exhausted' do
    it 'releases the regeneration lock' do
      fire_retries_exhausted(RegenerateChartsJob.new([chart.id], replace: false))

      expect(chart.reload.regenerating_since).to be_nil
    end

    it 'releases the lock for the single-chart job too' do
      fire_retries_exhausted(CreateChartStatisticsJob.new(chart.id))

      expect(chart.reload.regenerating_since).to be_nil
    end

    # Regression: reading the job from msg['class'] yields Sidekiq's JobWrapper, which has no
    # #deserialize — the NoMethodError is swallowed by the rescue and the lock is held forever.
    it 'does not swallow the payload and leave the lock held' do
      allow(Rails.logger).to receive(:error)

      fire_retries_exhausted(RegenerateChartsJob.new([chart.id], replace: false))

      expect(Rails.logger).not_to have_received(:error)
    end

    it 'logs and does not raise when the payload cannot be read' do
      allow(Rails.logger).to receive(:error)

      expect do
        RegenerateChartsJob.sidekiq_retries_exhausted_block.call({ 'args' => [] }, StandardError.new('boom'))
      end.not_to raise_error

      expect(Rails.logger).to have_received(:error).at_least(:once)
    end
  end
end
