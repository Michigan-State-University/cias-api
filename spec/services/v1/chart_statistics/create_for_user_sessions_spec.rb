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
end
