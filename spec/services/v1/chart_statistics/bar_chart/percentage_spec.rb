# frozen_string_literal: true

RSpec.describe V1::ChartStatistics::BarChart::Percentage do
  subject { described_class.new(data_collection, charts).generate }

  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health') }
  let!(:health_system) { create(:health_system, :with_health_system_admin, organization: organization) }
  let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, name: 'Health Clinic', health_system: health_system) }
  let!(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let!(:dashboard_sections) { create(:dashboard_section, name: 'Dashboard section', reporting_dashboard: reporting_dashboard) }
  let!(:bar_chart1) do
    create(:chart, name: 'percentage_bar_chart1', dashboard_section: dashboard_sections, chart_type: 'percentage_bar_chart', status: 'published')
  end
  let!(:bar_chart2) do
    create(:chart, name: 'percentage_bar_chart2', dashboard_section: dashboard_sections, chart_type: 'percentage_bar_chart', status: 'published')
  end
  let!(:other_chart) { create(:chart, name: 'bar_chart', dashboard_section: dashboard_sections, chart_type: 'bar_chart', status: 'published') }

  let!(:chart_matched_statistic1) do
    create_list(:chart_statistic, 10, label: 'Matched', organization: organization, health_system: health_system, chart: bar_chart1,
                                      health_clinic: health_clinic, filled_at: 2.months.ago)
  end
  let!(:chart_not_matched_statistic1) do
    create_list(:chart_statistic, 5, label: 'NotMatched', organization: organization, health_system: health_system, chart: bar_chart1,
                                     health_clinic: health_clinic, filled_at: 2.months.ago)
  end
  let!(:chart_matched_statistic2) do
    create_list(:chart_statistic, 3, label: 'Matched', organization: organization, health_system: health_system, chart: bar_chart1,
                                     health_clinic: health_clinic, filled_at: 1.month.ago)
  end
  let!(:chart_not_matched_statistic2) do
    create_list(:chart_statistic, 5, label: 'NotMatched', organization: organization, health_system: health_system, chart: bar_chart1,
                                     health_clinic: health_clinic, filled_at: 1.month.ago)
  end
  let(:data_collection) { ChartStatistic.all }
  let(:charts) { Chart.all }

  context 'when charts are publish' do
    it 'return correct aggregated data' do
      expect(subject).to include(
        {
          'chart_id' => bar_chart1.id,
          'data' => include(
            {
              'label' => chart_matched_statistic1.first.filled_at.strftime('%B %Y'),
              'value' => 66.67,
              'color' => '#C766EA',
              'population' => 15
            },
            {
              'label' => chart_matched_statistic2.first.filled_at.strftime('%B %Y'),
              'value' => 37.5,
              'color' => '#C766EA',
              'population' => 8
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

    context 'with data offset' do
      subject { described_class.new(data_collection, charts, data_offset).generate }

      let(:data_offset) { ((Time.current - 1.month.ago) / 1.day).to_i + 1 }

      it 'return correct data' do
        expect(subject).to include(
          {
            'chart_id' => bar_chart1.id,
            'data' => [
              {
                'label' => 1.month.ago.strftime('%B %Y'),
                'value' => 37.5,
                'color' => '#C766EA',
                'population' => 8
              },
              {
                'label' => Time.current.strftime('%B %Y'),
                'value' => 0,
                'color' => '#C766EA',
                'population' => 0
              }
            ],
            'population' => 23,
            'dashboard_section_id' => bar_chart1.dashboard_section_id
          },
          {
            'chart_id' => bar_chart2.id,
            'data' => [
              {
                'label' => 1.month.ago.strftime('%B %Y'),
                'value' => 0,
                'color' => '#C766EA',
                'population' => 0
              },
              {
                'label' => Time.current.strftime('%B %Y'),
                'value' => 0,
                'color' => '#C766EA',
                'population' => 0
              }
            ],
            'population' => 0,
            'dashboard_section_id' => bar_chart2.dashboard_section_id
          }
        )
      end
    end
  end

  context 'for one chart' do
    subject { described_class.new(data_collection, chart).generate }

    let(:chart) { bar_chart1 }

    it 'return correct data' do
      expect(subject).to include({
                                   'chart_id' => chart.id,
                                   'data' => [
                                     {
                                       'label' => 2.months.ago.strftime('%B %Y'),
                                       'value' => 66.67,
                                       'color' => '#C766EA',
                                       'population' => 15
                                     },
                                     {
                                       'label' => 1.month.ago.strftime('%B %Y'),
                                       'value' => 37.5,
                                       'color' => '#C766EA',
                                       'population' => 8
                                     }
                                   ],
                                   'population' => 23,
                                   'dashboard_section_id' => chart.dashboard_section_id
                                 })
    end
  end

  context 'when charts are different type' do
    let!(:bar_chart1) { create(:chart, name: 'bar_chart1', dashboard_section: dashboard_sections, chart_type: 'pie_chart') }
    let!(:bar_chart2) { create(:chart, name: 'bar_chart2', dashboard_section: dashboard_sections, chart_type: 'pie_chart') }

    it 'return empty array' do
      expect(subject).to eql([])
    end
  end

  context 'when the chart has Invalid / Insufficient Data rows' do
    # Deliberately OUTSIDE the range of every real row: `periodical_statistics` walks from
    # the first to the last `filled_at` of the chart's rows, so without the
    # constructor-scoped exclusion these would stretch the axis back three extra months.
    let!(:invalid_statistics) do
      create_list(:chart_statistic, 4, label: ChartStatistic::INSUFFICIENT_DATA_LABEL, organization: organization,
                                       health_system: health_system, chart: bar_chart1,
                                       health_clinic: health_clinic, filled_at: 5.months.ago)
    end

    it 'does not stretch the month axis' do
      data = subject.find { |entry| entry['chart_id'] == bar_chart1.id }

      expect(data['data'].pluck('label')).to eq(
        [2.months.ago.strftime('%B %Y'), 1.month.ago.strftime('%B %Y')]
      )
    end

    it 'excludes Invalid rows from the axis and the chart population' do
      data = subject.find { |entry| entry['chart_id'] == bar_chart1.id }

      # What the exclusion actually protects here: the axis span and the top-level
      # `population` (`entry_count_hash`). The series and the per-month denominator are
      # invalid-free by construction, because `data_for_chart` sums only the two configured
      # labels (`percentage.rb:9-12`) - a reserved-label count could never enter them.
      expect(data['data']).to eq(
        [
          { 'label' => 2.months.ago.strftime('%B %Y'), 'value' => 66.67, 'color' => '#C766EA', 'population' => 15 },
          { 'label' => 1.month.ago.strftime('%B %Y'), 'value' => 37.5, 'color' => '#C766EA', 'population' => 8 }
        ]
      )
      expect(data['population']).to eq(23)
    end
  end

  context 'for quarterly charts' do
    let!(:bar_chart1) do
      create(:chart, name: 'percentage_bar_chart1', dashboard_section: dashboard_sections, chart_type: 'percentage_bar_chart', status: 'published',
                     interval_type: :quarterly)
    end
    let!(:chart_matched_statistic1) do
      create_list(:chart_statistic, 10, label: 'Matched', organization: organization, health_system: health_system, chart: bar_chart1,
                                        health_clinic: health_clinic, filled_at: DateTime.now)
    end
    let!(:chart_not_matched_statistic1) do
      create_list(:chart_statistic, 5, label: 'NotMatched', organization: organization, health_system: health_system, chart: bar_chart1,
                                       health_clinic: health_clinic, filled_at: DateTime.now)
    end
    let!(:chart_matched_statistic2) do
      create_list(:chart_statistic, 3, label: 'Matched', organization: organization, health_system: health_system, chart: bar_chart1,
                                       health_clinic: health_clinic, filled_at: DateTime.now.prev_quarter)
    end
    let!(:chart_not_matched_statistic2) do
      create_list(:chart_statistic, 5, label: 'NotMatched', organization: organization, health_system: health_system, chart: bar_chart1,
                                       health_clinic: health_clinic, filled_at: DateTime.now.prev_quarter)
    end

    it 'return correct aggregated data' do
      expect(subject).to include(
        {
          'chart_id' => bar_chart1.id,
          'data' => include(
            {
              'label' => "Q#{(chart_matched_statistic1.first.filled_at.month / 3.0).ceil} #{chart_matched_statistic1.first.filled_at.year}",
              'value' => 66.67,
              'color' => '#C766EA',
              'population' => 15
            },
            {
              'label' => "Q#{(chart_matched_statistic2.first.filled_at.month / 3.0).ceil} #{chart_matched_statistic2.first.filled_at.year}",
              'value' => 37.5,
              'color' => '#C766EA',
              'population' => 8
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
end
