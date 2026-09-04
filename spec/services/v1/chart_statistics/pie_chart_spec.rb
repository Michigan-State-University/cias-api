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

  let!(:chart_matched_statistic1) do
    create_list(:chart_statistic, 10, label: 'Matched', organization: organization, health_system: health_system, chart: pie_chart1,
                                      health_clinic: health_clinic, filled_at: 2.months.ago)
  end
  let!(:chart_matched_statistic2) do
    create_list(:chart_statistic, 5, label: 'NotMatched', organization: organization, health_system: health_system, chart: pie_chart1,
                                     health_clinic: health_clinic, filled_at: 2.months.ago)
  end
  let!(:chart_matched_statistic3) do
    create_list(:chart_statistic, 3, label: 'NotMatched', organization: organization, health_system: health_system, chart: pie_chart1,
                                     health_clinic: health_clinic, filled_at: 1.month.ago)
  end

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

    context 'when charts are different type' do
      let!(:pie_chart1) { create(:chart, name: 'pie_chart1', dashboard_section: dashboard_sections, chart_type: 'bar_chart') }
      let!(:pie_chart2) { create(:chart, name: 'pie_chart2', dashboard_section: dashboard_sections, chart_type: 'bar_chart') }

      it 'return empty array' do
        expect(subject).to eql([])
      end
    end

    context 'when participants were recorded as Invalid / Insufficient Data' do
      let!(:chart_invalid_statistic) do
        create_list(:chart_statistic, 2, label: ChartStatistic::INSUFFICIENT_DATA_LABEL, organization: organization,
                                         health_system: health_system, chart: pie_chart1,
                                         health_clinic: health_clinic, filled_at: 1.month.ago)
      end

      it 'renders the reserved slice with the fixed grey rather than the default category color' do
        pie = subject.find { |entry| entry['chart_id'] == pie_chart1.id }
        invalid_slice = pie['data'].find { |datum| datum['label'] == ChartStatistic::INSUFFICIENT_DATA_LABEL }

        expect(invalid_slice).to eq(
          'label' => ChartStatistic::INSUFFICIENT_DATA_LABEL,
          'value' => 2,
          'color' => ChartStatistic::INSUFFICIENT_DATA_COLOR
        )
        # Without the special case the reserved label matches no pattern and would inherit
        # the default category's color, making the two visually indistinguishable.
        expect(invalid_slice['color']).not_to eq(pie_chart1.formula['default_pattern']['color'])
      end

      it 'keeps the reserved rows in the pie population and leaves the real slices alone' do
        pie = subject.find { |entry| entry['chart_id'] == pie_chart1.id }

        expect(pie['population']).to eq(20)
        expect(pie['data']).to include(
          { 'label' => 'Matched', 'value' => 10, 'color' => '#C766EA' },
          { 'label' => 'NotMatched', 'value' => 8, 'color' => '#E2B1F4' }
        )
      end
    end
  end
end
