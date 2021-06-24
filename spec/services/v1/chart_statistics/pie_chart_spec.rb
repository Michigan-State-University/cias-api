# frozen_string_literal: true

RSpec.describe V1::ChartStatistics::PieChart do
  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health') }
  let!(:health_system) { create(:health_system, :with_health_system_admin, organization: organization) }
  let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, name: 'Health Clinic', health_system: health_system) }
  let!(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let!(:dashboard_sections) { create(:dashboard_section, name: 'Dashboard section', reporting_dashboard: reporting_dashboard) }
  let!(:pie_chart1) { create(:chart, name: 'pie_chart1', dashboard_section: dashboard_sections, chart_type: 'pie_chart', status: 'published') }
  let!(:pie_chart2) { create(:chart, name: 'pie_chart2', dashboard_section: dashboard_sections, chart_type: 'pie_chart', status: 'published') }
  let!(:other_chart) { create(:chart, name: 'bar_chart', dashboard_section: dashboard_sections, chart_type: 'bar_chart', status: 'published') }

  let!(:chart_matched_statistic1) { create_list(:chart_statistic, 10, label: 'Matched', organization: organization, health_system: health_system, chart: pie_chart1, health_clinic: health_clinic, created_at: 2.months.ago) }
  let!(:chart_matched_statistic2) { create_list(:chart_statistic, 5, label: 'NotMatched', organization: organization, health_system: health_system, chart: pie_chart1, health_clinic: health_clinic, created_at: 2.months.ago) }
  let!(:chart_matched_statistic3) { create_list(:chart_statistic, 3, label: 'NotMatched', organization: organization, health_system: health_system, chart: pie_chart1, health_clinic: health_clinic, created_at: 1.month.ago) }

  let(:data_collection) { ChartStatistic.all }
  let(:charts) { Chart.all }

  context 'for collection' do
    subject { described_class.new(data_collection, charts).generate }

    context 'when charts are publish' do
      it 'return correct aggreagted data' do
        expect(subject).to include(
          {
            'chart_id' => pie_chart1.id,
            'data' => include(
              {
                'label' => 'Matched',
                'value' => 10,
                'color' => '#C766EA'
              },
              {
                'label' => 'NotMatched',
                'value' => 8,
                'color' => '#E2B1F4'
              }
            ),
            'population' => 18,
            'dashboard_section_id' => pie_chart1.dashboard_section_id
          },
          {
            'chart_id' => pie_chart2.id,
            'data' => [],
            'population' => 0,
            'dashboard_section_id' => pie_chart2.dashboard_section_id
          }
        )
      end
    end

    context 'when charts are draft' do
      let!(:pie_chart1) { create(:chart, name: 'pie_chart1', dashboard_section: dashboard_sections, chart_type: 'pie_chart') }
      let!(:pie_chart2) { create(:chart, name: 'pie_chart2', dashboard_section: dashboard_sections, chart_type: 'pie_chart') }

      it 'return empty array' do
        expect(subject).to eql([])
      end
    end
  end
end
