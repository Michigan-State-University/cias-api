# frozen_string_literal: true

RSpec.describe V1::ChartStatistics::Create do
  subject { described_class.call(chart, user_session, organization) }

  let(:organization) { create(:organization) }
  let(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let(:dashboard_section) { create(:dashboard_section, reporting_dashboard: reporting_dashboard) }
  let(:health_system) { create(:health_system, organization: organization) }
  let(:health_clinic) { create(:health_clinic, health_system: health_system) }

  let(:intervention) { create(:intervention, :published, organization: organization) }
  let(:session) { create(:session, intervention: intervention, variable: 'session_var') }
  let(:user_session) { create(:user_session, user: user, session: session, health_clinic: health_clinic, finished_at: user_session_finished_at) }

  let(:admin) { create(:user, :admin, :confirmed) }
  let(:user) { create(:user, :participant, :confirmed) }

  let(:filled_at) { DateTime.current }
  let(:chart) do
    create(:chart, formula: formula, dashboard_section: dashboard_section, status: 'published', chart_type: :pie_chart,
                   published_at: DateTime.now, date_range_start: DateTime.yesterday, date_range_end: DateTime.tomorrow)
  end
  let(:formula) do
    { 'payload' => 'session_var.fruit',
      'patterns' => [
        {
          'match' => '=1',
          'label' => 'Apple',
          'color' => '#C766EA'
        }
      ],
      'default_pattern' => {
        'label' => 'Banana',
        'color' => '#E2B1F4'
      } }
  end

  let!(:answer) { create(:answer_single, user_session: user_session, body: { data: [{ var: 'fruit', value: '1' }] }) }

  context "when the user session was finished within the chart's data range" do
    let(:user_session_finished_at) { DateTime.now }

    it 'creates a new chart statistic' do
      expect { subject }.to change(ChartStatistic, :count).by(1)
    end
  end

  context 'when the user session was finished near the end of the day in date_range_end' do
    let(:user_session_finished_at) { chart.date_range_end + 24.hours - 1.second }

    it 'creates a new chart statistic' do
      expect { subject }.to change(ChartStatistic, :count).by(1)
    end
  end

  context 'when the user session was finished just after the end of the day in date_range_end' do
    let(:user_session_finished_at) { chart.date_range_end + 24.hours + 1.second }

    it 'creates a new chart statistic' do
      expect { subject }.not_to change(ChartStatistic, :count)
    end
  end

  context "when the user session was finished before the chart's data range" do
    let(:user_session_finished_at) { DateTime.now - 1.week }

    it 'does not create a new chart statistic' do
      expect { subject }.not_to change(ChartStatistic, :count)
    end
  end

  context "when the user session was finished after the chart's data range" do
    let(:user_session_finished_at) { DateTime.now + 1.week }

    it 'does not create a new chart statistic' do
      expect { subject }.not_to change(ChartStatistic, :count)
    end
  end
end
