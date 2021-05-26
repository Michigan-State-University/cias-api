# frozen_string_literal: true

RSpec.describe V1::ChartStatistics::CreateForUserSessions do
  subject { described_class.call(pie_chart.id) }

  before_all do
    RSpec::Mocks.with_temporary_scope do
      allow_any_instance_of(Question).to receive(:execute_narrator).and_return(true)
    end
  end


  let_it_be(:organization) { create(:organization) }
  let_it_be(:health_system) { create(:health_system, organization: organization) }
  let_it_be(:health_clinic) { create(:health_clinic, health_system: health_system) }
  let_it_be(:intervention) { create(:intervention, :published, organization: organization) }
  let_it_be(:session) { create(:session, intervention: intervention, settings: { narrator: { "voice": false } }) }
  let_it_be(:user) { create(:user) }
  let_it_be(:user_session) { create(:user_session, session: session, user: user, health_clinic: health_clinic) }
  let_it_be(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let_it_be(:dashboard_section) { create(:dashboard_section, reporting_dashboard: reporting_dashboard) }

  let_it_be(:formula) do
    { 'payload' => 'color + sport',
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
  let_it_be(:answer1) do
    create(:answer_single, user_session: user_session, body: { data: [{ var: 'color', value: '1' }] })
  end
  let_it_be(:answer2) do
    create(:answer_single, user_session: user_session, body: { data: [{ var: 'sport', value: '1' }] })
  end

  it 'create chart statistic' do
    expect { subject }.to change(ChartStatistic, :count).by(1)
    chart_statistics = ChartStatistic.where(
      organization: organization,
      health_system: health_system,
      health_clinic: health_clinic,
      user: user
    )

    expect(chart_statistics.exists?(label: 'Label1', chart: pie_chart)).to eq true
  end
end
