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
              'population' => 15,
              'invalidValue' => 0
            },
            {
              'label' => chart_matched_statistic2.first.filled_at.strftime('%B %Y'),
              'value' => 37.5,
              'color' => '#C766EA',
              'population' => 8,
              'invalidValue' => 0
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
                'population' => 8,
                'invalidValue' => 0
              },
              {
                'label' => Time.current.strftime('%B %Y'),
                'value' => 0,
                'color' => '#C766EA',
                'population' => 0,
                'invalidValue' => 0
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
                'population' => 0,
                'invalidValue' => 0
              },
              {
                'label' => Time.current.strftime('%B %Y'),
                'value' => 0,
                'color' => '#C766EA',
                'population' => 0,
                'invalidValue' => 0
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
                                       'population' => 15,
                                       'invalidValue' => 0
                                     },
                                     {
                                       'label' => 1.month.ago.strftime('%B %Y'),
                                       'value' => 37.5,
                                       'color' => '#C766EA',
                                       'population' => 8,
                                       'invalidValue' => 0
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
    # Deliberately OUTSIDE the range of every real row: `periodical_statistics` walks from the
    # first to the last `filled_at` of the chart's rows, so these now stretch the axis back three
    # extra months - intended, since the period had participants.
    let!(:invalid_statistics) do
      create_list(:chart_statistic, 4, label: ChartStatistic::INSUFFICIENT_DATA_LABEL, organization: organization,
                                       health_system: health_system, chart: bar_chart1,
                                       health_clinic: health_clinic, filled_at: 5.months.ago)
    end

    it 'stretches the month axis to cover the Invalid-only period' do
      data = subject.find { |entry| entry['chart_id'] == bar_chart1.id }

      expect(data['data'].pluck('label')).to eq(
        [5, 4, 3, 2, 1].map { |n| n.months.ago.strftime('%B %Y') }
      )
    end

    it 'counts Invalid rows in the denominator and carries them for the tooltip' do
      data = subject.find { |entry| entry['chart_id'] == bar_chart1.id }

      # The Invalid-only period reads 0% matched against a population of 4 - it had four
      # participants, none of whom answered enough. No second series: this chart type renders a
      # single bar, so `invalidValue` exists for the hover text only.
      expect(data['data']).to eq(
        [
          { 'label' => 5.months.ago.strftime('%B %Y'), 'value' => 0, 'color' => '#C766EA', 'population' => 4, 'invalidValue' => 4 },
          { 'label' => 4.months.ago.strftime('%B %Y'), 'value' => 0, 'color' => '#C766EA', 'population' => 0, 'invalidValue' => 0 },
          { 'label' => 3.months.ago.strftime('%B %Y'), 'value' => 0, 'color' => '#C766EA', 'population' => 0, 'invalidValue' => 0 },
          { 'label' => 2.months.ago.strftime('%B %Y'), 'value' => 66.67, 'color' => '#C766EA', 'population' => 15, 'invalidValue' => 0 },
          { 'label' => 1.month.ago.strftime('%B %Y'), 'value' => 37.5, 'color' => '#C766EA', 'population' => 8, 'invalidValue' => 0 }
        ]
      )
      expect(data['population']).to eq(27)
    end
  end

  context 'when Invalid rows share a period with counted participants' do
    # The headline behaviour change: the same data now reports a LOWER percentage, because the
    # participants who answered too little are part of the denominator instead of vanishing.
    let!(:invalid_statistics) do
      create_list(:chart_statistic, 5, label: ChartStatistic::INSUFFICIENT_DATA_LABEL, organization: organization,
                                       health_system: health_system, chart: bar_chart1,
                                       health_clinic: health_clinic, filled_at: 2.months.ago)
    end

    it 'lowers the matched percentage for that period' do
      data = subject.find { |entry| entry['chart_id'] == bar_chart1.id }
      period = data['data'].find { |datum| datum['label'] == 2.months.ago.strftime('%B %Y') }

      # 10 matched of (10 + 5 + 5) = 50.0 %. Before Invalid entered the denominator the same
      # rows reported 10 of 15 = 66.67 %.
      expect(period).to eq(
        'label' => 2.months.ago.strftime('%B %Y'), 'value' => 50.0, 'color' => '#C766EA',
        'population' => 20, 'invalidValue' => 5
      )
    end

    it 'leaves a period with no Invalid rows untouched' do
      data = subject.find { |entry| entry['chart_id'] == bar_chart1.id }
      period = data['data'].find { |datum| datum['label'] == 1.month.ago.strftime('%B %Y') }

      expect(period['value']).to eq(37.5)
      expect(period['invalidValue']).to eq(0)
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
              'population' => 15,
              'invalidValue' => 0
            },
            {
              'label' => "Q#{(chart_matched_statistic2.first.filled_at.month / 3.0).ceil} #{chart_matched_statistic2.first.filled_at.year}",
              'value' => 37.5,
              'color' => '#C766EA',
              'population' => 8,
              'invalidValue' => 0
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

  # The multi-band consequence is sharper here than on the numeric bar: bands 2..n are absent
  # from the DENOMINATOR too, so the published percentage is a share of a population smaller
  # than the chart's own `population` field. A researcher reading "50% matched" against a
  # population of 15 is reading 3 of 6, not 3 of 15.
  context 'when the chart formula defines more than one case' do
    let!(:multi_band_chart) do
      create(:chart, name: 'severity', dashboard_section: dashboard_sections, chart_type: 'percentage_bar_chart',
                     status: 'published',
                     formula: {
                       'payload' => 'phq.total',
                       'patterns' => [
                         { 'match' => '>=30', 'label' => 'Severe', 'color' => '#C766EA' },
                         { 'match' => '>=20', 'label' => 'Moderate', 'color' => '#FFC062' },
                         { 'match' => '>=10', 'label' => 'Mild', 'color' => '#7ED0C1' }
                       ],
                       'default_pattern' => { 'label' => 'Minimal', 'color' => '#E2B1F4' },
                       'min_answered_variables' => 0,
                       'positive_despite_missing_data' => false
                     })
    end

    let!(:band_rows) do
      { 'Severe' => 3, 'Moderate' => 4, 'Mild' => 5, 'Minimal' => 2,
        ChartStatistic::INSUFFICIENT_DATA_LABEL => 1 }.map do |label, count|
        create_list(:chart_statistic, count, label: label, organization: organization, health_system: health_system,
                                             chart: multi_band_chart, health_clinic: health_clinic, filled_at: 1.month.ago)
      end
    end

    let(:chart_entry) { subject.find { |entry| entry['chart_id'] == multi_band_chart.id } }

    it 'divides by the first case, the default and Invalid only' do
      expect(chart_entry['data'].first).to eq(
        'label' => 1.month.ago.strftime('%B %Y'),
        'color' => '#C766EA',
        'population' => 6,
        'value' => 50.0,
        'invalidValue' => 1
      )
    end

    it "publishes a datum population smaller than the chart's own population" do
      # 3 Severe + 2 Minimal + 1 Invalid = 6, against 15 rows in the period. Every Moderate
      # and every Mild is outside the percentage entirely.
      expect(chart_entry['population']).to eq(15)
      expect(chart_entry['data'].first['population']).to eq(6)
    end
  end
end
