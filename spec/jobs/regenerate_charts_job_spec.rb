# frozen_string_literal: true

RSpec.describe RegenerateChartsJob, type: :job do
  let(:organization) { create(:organization) }
  let(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let(:dashboard_section) { create(:dashboard_section, reporting_dashboard: reporting_dashboard) }
  let(:chart) { create(:chart, dashboard_section: dashboard_section) }
  let(:user) { create(:user, :confirmed, :admin) }

  describe 'argument binding' do
    # `replace` used to be the second POSITIONAL parameter, which is how a user id could be shifted
    # into it and silently select the destructive path. It is a keyword now, so the mis-binding this
    # example guards has changed shape: what can still go wrong is the job passing the wrong value
    # on. Fails under `replace: true`, under a hardcoded literal, and under crossed keywords.
    it 'passes replace straight through to the regeneration service' do
      allow(V1::Charts::Regenerate).to receive(:call)

      described_class.new.perform([chart.id], replace: false, user_id: user.id)

      expect(V1::Charts::Regenerate).to have_received(:call).with([chart.id], replace: false)
    end

    it 'passes replace: true through unchanged' do
      allow(V1::Charts::Regenerate).to receive(:call)

      described_class.new.perform([chart.id], replace: true)

      expect(V1::Charts::Regenerate).to have_received(:call).with([chart.id], replace: true)
    end

    # The keywords have to survive ActiveJob's serialize/deserialize round trip, which is the one
    # thing the direct `#perform` examples above cannot see. A ruby2_keywords regression would turn
    # `replace:` into a positional Hash — truthy, and therefore DESTRUCTIVE.
    it 'binds the keywords correctly after a serialize/deserialize round trip' do
      allow(V1::Charts::Regenerate).to receive(:call)
      payload = described_class.new([chart.id], replace: false, user_id: user.id).serialize

      ActiveJob::Base.execute(payload)

      expect(V1::Charts::Regenerate).to have_received(:call).with([chart.id], replace: false)
    end
  end

  describe 'destructiveness' do
    # summary.md decision 2: assert the argument AND prove row survival at job level.
    it 'leaves existing ChartStatistic rows intact with their ids when replace is false' do
      existing = create(:chart_statistic, chart: chart, organization: organization)

      described_class.new.perform([chart.id], replace: false, user_id: user.id)

      expect(ChartStatistic.where(chart_id: chart.id).pluck(:id)).to eq([existing.id])
    end

    it 'destroys and replays when replace is true' do
      create(:chart_statistic, chart: chart, organization: organization)

      expect { described_class.new.perform([chart.id], replace: true, user_id: user.id) }
        .to change { ChartStatistic.where(chart_id: chart.id).count }.to(0)
    end
  end

  describe 'the completion email' do
    before { allow(V1::Charts::Regenerate).to receive(:call) }

    it 'emails the triggering user when the run finishes' do
      expect { described_class.new.perform([chart.id], replace: false, user_id: user.id) }
        .to change { ActionMailer::Base.deliveries.count }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([user.email])
      expect(mail.subject).to include(chart.name)
    end

    it 'sends nothing when the user turned email notifications off' do
      user.update!(email_notification: false)

      expect { described_class.new.perform([chart.id], replace: false, user_id: user.id) }
        .not_to change { ActionMailer::Base.deliveries.count }
    end

    # The batch caller (RegenerateForOrganizations) and the rake task pass no user id.
    it 'sends nothing when there is no triggering user' do
      expect { described_class.new.perform([chart.id], replace: false) }
        .not_to change { ActionMailer::Base.deliveries.count }
    end

    it 'sends nothing when the triggering user has since been deleted' do
      deleted_user_id = user.id
      user.destroy!

      expect { described_class.new.perform([chart.id], replace: false, user_id: deleted_user_id) }
        .not_to change { ActionMailer::Base.deliveries.count }
    end

    # A failed run re-raises from CreateForUserSessions, so the mail line must be unreachable —
    # "your chart has been regenerated" after a failure is worse than no email at all.
    it 'does not email when the regeneration raises' do
      allow(V1::Charts::Regenerate).to receive(:call).and_raise(StandardError, 'boom')

      expect do
        suppress(StandardError) { described_class.new.perform([chart.id], replace: false, user_id: user.id) }
      end.not_to change { ActionMailer::Base.deliveries.count }
    end
  end
end
