# frozen_string_literal: true

RSpec.describe V1::ChartStatistics::CreateForUserSessions do
  subject { described_class.call(pie_chart.id) }

  let_it_be(:organization) { create(:organization) }
  let_it_be(:health_system) { create(:health_system, organization: organization) }
  let_it_be(:health_clinic) { create(:health_clinic, health_system: health_system) }
  let_it_be(:intervention) { create(:intervention, :published, organization: organization) }
  let_it_be(:user) { create(:user) }
  let_it_be(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let_it_be(:dashboard_section) { create(:dashboard_section, reporting_dashboard: reporting_dashboard) }
  let_it_be(:session_variable) { 'session_var' }
  let_it_be(:formula) do
    { 'payload' => "#{session_variable}.color + #{session_variable}.sport",
      'patterns' => [
        {
          'match' => '=2',
          'label' => 'Label1',
          'color' => '#C766EA'
        }
      ],
      'default_pattern' => {
        'label' => 'Other',
        'color' => '#E2B1F4'
      } }
  end

  let_it_be(:pie_chart) do
    create(:chart, formula: formula, dashboard_section: dashboard_section, published_at: Time.current,
                   chart_type: Chart.chart_types[:pie_chart])
  end

  before_all do
    RSpec::Mocks.with_temporary_scope do
      allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)

      session = create(:session, intervention: intervention, variable: session_variable)
      user_session = create(:user_session, session: session, user: user, health_clinic: health_clinic, finished_at: DateTime.now)

      @answer1 = create(:answer_single, user_session: user_session, body: { data: [{ var: 'color', value: '1' }] })
      @answer2 = create(:answer_single, user_session: user_session, body: { data: [{ var: 'sport', value: '1' }] })

      user_session2 = create(:user_session, session: session, user: create(:user, :guest), health_clinic: health_clinic)

      @answer3 = create(:answer_single, user_session: user_session2, body: { data: [{ var: 'color', value: '1' }] })
      @answer4 = create(:answer_single, user_session: user_session2, body: { data: [{ var: 'sport', value: '1' }] })
    end
  end

  let(:answer1) { @answer1 }
  let(:answer2) { @answer2 }

  it 'create chart statistic' do
    expect { subject }.to change(ChartStatistic, :count).by(1)
    chart_statistics = ChartStatistic.where(
      organization: organization,
      health_system: health_system,
      health_clinic: health_clinic,
      user: user
    )

    expect(chart_statistics.exists?(label: 'Label1', chart: pie_chart)).to be true
  end

  describe 'regeneration lock' do
    # Needs the real formula: without it no user session qualifies, `create_statistics` is a no-op
    # and these examples pass with no lock held at all.
    let(:lock_chart) { create(:chart, formula: formula, dashboard_section: dashboard_section) }

    it 'releases the lock after a successful run' do
      described_class.call(lock_chart.id)

      expect(lock_chart.reload.regenerating_since).to be_nil
    end

    # retry_on keeps a retry queued for hours, so releasing here would advertise "idle" the whole
    # time and let a second run start alongside the queued one.
    it 'holds the lock when the run raises' do
      allow_any_instance_of(described_class).to receive(:create_statistics).and_raise(StandardError, 'boom')

      expect { described_class.call(lock_chart.id) }.to raise_error('boom')
      expect(lock_chart.reload.regenerating_since).to be_present
    end

    it 'skips entirely when the chart is already regenerating' do
      lock_chart.update!(regenerating_since: 5.minutes.ago)
      allow(V1::ChartStatistics::Create).to receive(:call)

      described_class.call(lock_chart.id)

      expect(V1::ChartStatistics::Create).not_to have_received(:call)
    end

    it 'leaves the existing lock timestamp untouched when it skips' do
      locked_at = 5.minutes.ago.change(usec: 0)
      lock_chart.update!(regenerating_since: locked_at)

      described_class.call(lock_chart.id)

      expect(lock_chart.reload.regenerating_since).to be_within(1.second).of(locked_at)
    end

    # F1 from the fix-verification round: the `.unscoped` in #lock_acquired? is the single most
    # important line in this phase — without it Chart's `default_scope { order(:position) }` makes
    # Arel rewrite the UPDATE into an ordered sub-SELECT and two concurrent runs BOTH acquire. It had
    # no regression coverage; a comment was the only thing protecting it.
    it 'acquires with a flat UPDATE, not an ordered sub-select' do
      statements = []
      subscriber = lambda do |*args|
        sql = ActiveSupport::Notifications::Event.new(*args).payload[:sql]
        statements << sql if sql.start_with?('UPDATE "charts"')
      end

      ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
        described_class.call(lock_chart.id)
      end

      expect(statements.first).not_to include('SELECT')
    end

    # F2: the release is conditional on the token this run wrote, so a run whose lock was taken over
    # by the TTL cannot clear the new owner's lock.
    it 'does not release a lock that another run has taken over' do
      service = described_class.new(lock_chart.id)
      service.send(:lock_acquired?)
      taken_over_at = 1.minute.ago.change(usec: 0)
      lock_chart.update!(regenerating_since: taken_over_at)

      service.send(:release_lock)

      expect(lock_chart.reload.regenerating_since).to be_within(1.second).of(taken_over_at)
    end

    # The TTL is what lets the queued retry make progress. Without it, holding the lock on failure
    # wedges the chart forever, because retry_on absorbs the exception and Sidekiq never sees a
    # failure to exhaust.
    it 'takes over a lock older than LOCK_TTL' do
      lock_chart.update!(regenerating_since: (described_class::LOCK_TTL + 15.minutes).ago)

      described_class.call(lock_chart.id)

      expect(lock_chart.reload.regenerating_since).to be_nil
    end

    it 'does not take over a lock inside LOCK_TTL' do
      held_at = (described_class::LOCK_TTL - 15.minutes).ago.change(usec: 0)
      lock_chart.update!(regenerating_since: held_at)

      described_class.call(lock_chart.id)

      expect(lock_chart.reload.regenerating_since).to be_within(1.second).of(held_at)
    end

    # The regression that would have caught the wedge: a run fails, the lock is held, and the retry
    # must eventually be able to do the work rather than skipping forever.
    it 'lets a later run proceed once the held lock has aged past the TTL' do
      allow_any_instance_of(described_class).to receive(:create_statistics).and_raise(StandardError, 'boom')
      expect { described_class.call(lock_chart.id) }.to raise_error('boom')
      expect(lock_chart.reload.regenerating_since).to be_present

      lock_chart.update!(regenerating_since: (described_class::LOCK_TTL + 1.minute).ago)
      allow_any_instance_of(described_class).to receive(:create_statistics).and_call_original

      described_class.call(lock_chart.id)

      expect(lock_chart.reload.regenerating_since).to be_nil
    end

    # The destroy now happens inside the lock, per chart. Previously V1::Charts::Regenerate destroyed
    # every chart's rows up front, so a chart that was then skipped lost its data permanently.
    it 'does not destroy rows for a chart it skips' do
      existing = create(:chart_statistic, chart: lock_chart, organization: organization)
      lock_chart.update!(regenerating_since: 5.minutes.ago)

      V1::Charts::Regenerate.call([lock_chart.id], replace: true)

      expect(ChartStatistic.where(chart_id: lock_chart.id).pluck(:id)).to eq([existing.id])
    end
  end

  describe 'duplicate detection' do
    let(:dup_chart) { create(:chart, dashboard_section: dashboard_section) }

    before { allow(V1::ChartStatistics::Create).to receive(:call) }

    it 'warns when duplicate cells survive the run' do
      duplicated_user = create(:user)
      2.times do
        create(:chart_statistic, chart: dup_chart, organization: organization,
                                 health_system: health_system, health_clinic: health_clinic, user: duplicated_user)
      end
      allow(Rails.logger).to receive(:warn)

      described_class.call(dup_chart.id)

      expect(Rails.logger).to have_received(:warn).with(/duplicate cell/)
    end

    it 'is silent on a clean run' do
      allow(Rails.logger).to receive(:warn)

      described_class.call(dup_chart.id)

      expect(Rails.logger).not_to have_received(:warn).with(/duplicate cell/)
    end
  end
end
