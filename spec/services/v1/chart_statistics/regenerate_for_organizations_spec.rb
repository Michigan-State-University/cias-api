# frozen_string_literal: true

RSpec.describe V1::ChartStatistics::RegenerateForOrganizations do
  let(:organization) { create(:organization) }
  let(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let(:dashboard_section) { create(:dashboard_section, reporting_dashboard: reporting_dashboard) }
  let!(:chart) { create(:chart, dashboard_section: dashboard_section, status: :data_collection) }

  # `replace` decides between a replay and a `destroy_all`, and this batch caller is where the
  # positional signature used to bind a user id into it. The signature is keyword-based now, so
  # there is no slot to shift, but the destructive branch is unrecoverable and these calls stay
  # pinned: asserting "a job was enqueued" cannot tell the two paths apart — assert the arguments.
  describe 'argument binding' do
    it 'enqueues with replace: false and no user_id' do
      allow(RegenerateChartsJob).to receive(:perform_later)

      described_class.call([organization.id], replace: false)

      expect(RegenerateChartsJob).to have_received(:perform_later).with([chart.id], replace: false)
    end

    it 'passes replace: true through unchanged' do
      allow(RegenerateChartsJob).to receive(:perform_later)

      described_class.call([organization.id], replace: true)

      expect(RegenerateChartsJob).to have_received(:perform_later).with([chart.id], replace: true)
    end

    # Spelled out rather than left to the matcher: this fails if `replace` is ever passed
    # positionally again, if a second positional argument appears beside the ids, or if the batch
    # caller starts inventing a user_id (it has no user — the completion email must not fire here).
    it 'passes the ids positionally and replace as a keyword, with nothing else' do
      captured_args = nil
      captured_kwargs = nil
      allow(RegenerateChartsJob).to receive(:perform_later) do |*args, **kwargs|
        captured_args = args
        captured_kwargs = kwargs
      end

      described_class.call([organization.id], replace: false)

      expect(captured_args).to eq([[chart.id]])
      expect(captured_kwargs).to eq({ replace: false })
    end
  end

  describe 'batching' do
    it 'slices when the chart count exceeds the batch size' do
      allow(RegenerateChartsJob).to receive(:perform_later)
      create(:chart, dashboard_section: dashboard_section, status: :data_collection)

      described_class.call([organization.id], replace: false, batch_size: 1)

      expect(RegenerateChartsJob).to have_received(:perform_later).with(anything, replace: false).twice
    end

    it 'does nothing for an organization with no collecting charts' do
      allow(RegenerateChartsJob).to receive(:perform_later)
      chart.update!(status: :draft)

      described_class.call([organization.id], replace: false)

      expect(RegenerateChartsJob).not_to have_received(:perform_later)
    end
  end
end
