# frozen_string_literal: true

RSpec.describe V1::ChartStatistics::GenerateChartStats::GenerateBarChartStats::GenerateNumericBarChartStats do
  subject { described_class.new(data_collection, chart).generate_for_chart }

  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health') }
  let!(:health_system) { create(:health_system, :with_health_system_admin, organization: organization) }
  let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, name: 'Health Clinic', health_system: health_system) }
  let!(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let!(:dashboard_sections) { create(:dashboard_section, name: 'Dashboard section', reporting_dashboard: reporting_dashboard) }
  let!(:bar_chart1) { create(:chart, name: 'bar_chart1', dashboard_section: dashboard_sections, chart_type: 'bar_chart', status: 'published') }
  let!(:bar_chart2) { create(:chart, name: 'bar_chart2', dashboard_section: dashboard_sections, chart_type: 'bar_chart', status: 'published') }
  let!(:other_chart) { create(:chart, name: 'pie_chart', dashboard_section: dashboard_sections, chart_type: 'pie_chart', status: 'published') }
  let(:chart) { bar_chart1 }

  let!(:chart_matched_statistic1) { create_list(:chart_statistic, 10, label: 'Matched', organization: organization, health_system: health_system, chart: bar_chart1, health_clinic: health_clinic, created_at: 2.months.ago) }
  let!(:chart_not_matched_statistic1) { create_list(:chart_statistic, 5, label: 'NotMatched', organization: organization, health_system: health_system, chart: bar_chart1, health_clinic: health_clinic, created_at: 2.months.ago) }
  let!(:chart_matched_statistic2) { create_list(:chart_statistic, 3, label: 'Matched', organization: organization, health_system: health_system, chart: bar_chart1, health_clinic: health_clinic, created_at: 1.month.ago) }
  let!(:chart_not_matched_statistic2) { create_list(:chart_statistic, 5, label: 'NotMatched', organization: organization, health_system: health_system, chart: bar_chart1, health_clinic: health_clinic, created_at: 1.month.ago) }

  let(:data_collection) { ChartStatistic.all }
  let(:charts) { Chart.all }

  context 'for all charts' do
    subject { described_class.new(data_collection, charts).generate }

    context 'when charts are publish' do
      it 'return correct aggreagted data' do
        expect(subject).to include(
          {
            'chart_id' => bar_chart1.id,
            'data' => include(
              {
                'label' => chart_matched_statistic1.first.created_at.strftime('%B %Y'),
                'value' => 10,
                'color' => '#C766EA',
                'notMatchedValue' => 5
              },
              {
                'label' => chart_matched_statistic2.first.created_at.strftime('%B %Y'),
                'value' => 3,
                'color' => '#C766EA',
                'notMatchedValue' => 5
              }
            ),
            'population' => 23,
            'dashboard_section_id' => bar_chart1.dashboard_section_id
          },
          {
            'chart_id' => bar_chart2.id,
            'data' => [],
            'population' => 0,
            'dashboard_section_id' => bar_chart2.dashboard_section_id
          }
        )
      end
    end

    context 'when charts are draft' do
      let!(:bar_chart1) { create(:chart, name: 'bar_chart1', dashboard_section: dashboard_sections, chart_type: 'bar_chart') }
      let!(:bar_chart2) { create(:chart, name: 'bar_chart2', dashboard_section: dashboard_sections, chart_type: 'bar_chart') }

      it 'return empty array' do
        expect(subject).to eql([])
      end
    end
  end

  context 'for one chart'

  it 'return correct data' do
    p subject
    expect(subject).to include({
                                 'chart_id' => chart.id,
                                 'data' => [
                                   {
                                     'label' => chart_matched_statistic1.first.created_at.strftime('%B %Y'),
                                     'value' => 10,
                                     'color' => '#C766EA',
                                     'notMatchedValue' => 5
                                   },
                                   {
                                     'label' => chart_matched_statistic2.first.created_at.strftime('%B %Y'),
                                     'value' => 3,
                                     'color' => '#C766EA',
                                     'notMatchedValue' => 5
                                   }
                                 ],
                                 'population' => 23,
                                 'dashboard_section_id' => chart.dashboard_section_id
                               })
  end
end
