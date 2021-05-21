# frozen_string_literal: true

RSpec.describe V1::UserSessions::ChartStatistics::Create do
  subject { described_class.call(user_session) }

  let_it_be(:organization) { create(:organization) }
  let_it_be(:health_system) { create(:health_system, organization: organization) }
  let_it_be(:health_clinic) { create(:health_clinic, health_system: health_system) }
  let_it_be(:intervention) { create(:intervention, :published, organization: organization) }
  let_it_be(:session) { create(:session, intervention: intervention) }
  let_it_be(:user) { create(:user) }
  let_it_be(:user_session) { create(:user_session, session: session, user: user, health_clinic: health_clinic) }
  let_it_be(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let_it_be(:dashboard_section) { create(:dashboard_section, reporting_dashboard: reporting_dashboard) }

  context 'when chart is published' do
    let_it_be(:formula1) do
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
    let_it_be(:formula2) do
      { 'payload' => 'color + sport',
        'patterns' => [
          {
            'match' => '=5',
            'label' => 'Label1',
            'color' => '#C766EA'
          }
        ],
        'default_pattern' => {
          'label' => 'Other',
          'color' => '#E2B1F4'
        } }
    end
    let_it_be(:formula3) do
      { 'payload' => 'color + sport',
        'patterns' => [
          {
            'match' => '=2',
            'color' => '#C766EA'
          }
        ],
        'default_pattern' => {
          'color' => '#E2B1F4'
        } }
    end
    let_it_be(:formula4) do
      { 'payload' => 'color + sport',
        'patterns' => [
          {
            'match' => '=4',
            'color' => '#C766EA'
          }
        ],
        'default_pattern' => {
          'color' => '#E2B1F4'
        } }
    end
    let_it_be(:pie_chart1) do
      create(:chart, formula: formula1, dashboard_section: dashboard_section, published_at: Time.current,
                     chart_type: Chart.chart_types[:pie_chart])
    end
    let_it_be(:pie_chart2) do
      create(:chart, formula: formula2, dashboard_section: dashboard_section, published_at: Time.current,
                     chart_type: Chart.chart_types[:pie_chart])
    end
    let_it_be(:bar_chart1) do
      create(:chart, formula: formula3, dashboard_section: dashboard_section, published_at: Time.current,
                     chart_type: Chart.chart_types[:bar_chart])
    end
    let_it_be(:bar_chart2) do
      create(:chart, formula: formula4, dashboard_section: dashboard_section, published_at: Time.current,
                     chart_type: Chart.chart_types[:bar_chart])
    end

    context 'when user session contains all values of chart formula' do
      let_it_be(:answer1) do
        create(:answer_single, user_session: user_session, body: { data: [{ var: 'color', value: '1' }] })
      end
      let_it_be(:answer2) do
        create(:answer_single, user_session: user_session, body: { data: [{ var: 'sport', value: '1' }] })
      end

      it 'create chart statistics for bart charts and pie charts' do
        expect { subject }.to change(ChartStatistic, :count).by(4)
        chart_statistics = ChartStatistic.where(
          organization: organization,
          health_system: health_system,
          health_clinic: health_clinic,
          user: user
        )

        expect(chart_statistics.exists?(label: 'Label1', chart: pie_chart1)).to eq true
        expect(chart_statistics.exists?(label: 'Other', chart: pie_chart2)).to eq true
        expect(chart_statistics.exists?(label: 'Matched', chart: bar_chart1)).to eq true
        expect(chart_statistics.exists?(label: 'NotMatched', chart: bar_chart2)).to eq true
      end
    end

    context "when user session doesn't contain all values of chart formula" do
      let!(:answer1) do
        create(:answer_single, user_session: user_session, body: { data: [{ var: 'color', value: '1' }] })
      end

      it "Don't create chart statistic" do
        expect { subject }.not_to change(ChartStatistic, :count)
      end
    end

    context 'when exists chart statistic with specific fields' do
      let!(:chart_statistic) do
        create(:chart_statistic, label: 'Label1', organization: organization, health_system: health_system,
                                 health_clinic: health_clinic, chart: pie_chart1, user: user)
      end

      it "Don't create chart statistic" do
        expect { subject }.not_to change(ChartStatistic, :count)
      end
    end
  end

  context "when chart doesn't published" do
    let!(:chart) { create(:chart, dashboard_section: dashboard_section, published_at: nil) }

    it "Don't create chart statistic" do
      expect { subject }.not_to change(ChartStatistic, :count)
    end
  end
end

