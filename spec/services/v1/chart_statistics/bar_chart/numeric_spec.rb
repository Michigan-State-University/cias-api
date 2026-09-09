# frozen_string_literal: true

RSpec.describe V1::ChartStatistics::BarChart::Numeric do
  subject { described_class.new(data_collection, charts).generate }

  let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin, name: 'Michigan Public Health') }
  let!(:health_system) { create(:health_system, :with_health_system_admin, organization: organization) }
  let!(:health_clinic) { create(:health_clinic, :with_health_clinic_admin, name: 'Health Clinic', health_system: health_system) }
  let!(:reporting_dashboard) { create(:reporting_dashboard, organization: organization) }
  let!(:dashboard_sections) { create(:dashboard_section, name: 'Dashboard section', reporting_dashboard: reporting_dashboard) }
  let!(:bar_chart1) { create(:chart, name: 'bar_chart1', dashboard_section: dashboard_sections, chart_type: 'bar_chart', status: 'published') }
  let!(:bar_chart2) { create(:chart, name: 'bar_chart2', dashboard_section: dashboard_sections, chart_type: 'bar_chart', status: 'published') }
  let!(:other_chart) { create(:chart, name: 'pie_chart', dashboard_section: dashboard_sections, chart_type: 'pie_chart', status: 'published') }
  let(:chart) { bar_chart1 }

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

  context 'for all charts' do
    context 'when charts are publish' do
      it 'return correct aggregated data' do
        expect(subject).to include(
          {
            'chart_id' => bar_chart1.id,
            'data' => include(
              {
                'label' => chart_matched_statistic1.first.filled_at.strftime('%B %Y'),
                'value' => 10,
                'color' => '#C766EA',
                'notMatchedValue' => 5,
                'invalidValue' => 0
              },
              {
                'label' => chart_matched_statistic2.first.filled_at.strftime('%B %Y'),
                'value' => 3,
                'color' => '#C766EA',
                'notMatchedValue' => 5,
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

    context 'when charts are different type' do
      let!(:bar_chart1) { create(:chart, name: 'bar_chart1', dashboard_section: dashboard_sections, chart_type: 'pie_chart') }
      let!(:bar_chart2) { create(:chart, name: 'bar_chart2', dashboard_section: dashboard_sections, chart_type: 'pie_chart') }

      it 'return empty array' do
        expect(subject).to eql([])
      end
    end

    context 'with data offset' do
      subject { described_class.new(data_collection, chart, data_offset).generate }

      let(:data_offset) { ((Time.current - 1.month.ago) / 1.day).to_i + 1 }

      it 'return correct data' do
        expect(subject).to include(
          {
            'chart_id' => chart.id,
            'data' => [
              {
                'label' => 1.month.ago.strftime('%B %Y'),
                'value' => 3,
                'color' => '#C766EA',
                'notMatchedValue' => 5,
                'invalidValue' => 0
              },
              {
                'label' => Time.current.strftime('%B %Y'),
                'value' => 0,
                'color' => '#C766EA',
                'notMatchedValue' => 0,
                'invalidValue' => 0
              }
            ],
            'population' => 23,
            'dashboard_section_id' => chart.dashboard_section_id
          }
        )
      end
    end
  end

  context 'when the chart has Invalid / Insufficient Data rows' do
    # Deliberately OUTSIDE the range of every real row: `periodical_statistics` walks from the
    # first to the last `filled_at` of the chart's rows, so these now stretch the axis back three
    # extra months. That is the intended behaviour - a period that had participants must not be
    # hidden just because none of them answered enough.
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

    it 'publishes the Invalid count as its own series value' do
      data = subject.find { |entry| entry['chart_id'] == bar_chart1.id }

      expect(data['data']).to eq(
        [
          { 'label' => 5.months.ago.strftime('%B %Y'), 'value' => 0, 'color' => '#C766EA', 'notMatchedValue' => 0,
            'invalidValue' => 4 },
          { 'label' => 4.months.ago.strftime('%B %Y'), 'value' => 0, 'color' => '#C766EA', 'notMatchedValue' => 0,
            'invalidValue' => 0 },
          { 'label' => 3.months.ago.strftime('%B %Y'), 'value' => 0, 'color' => '#C766EA', 'notMatchedValue' => 0,
            'invalidValue' => 0 },
          { 'label' => 2.months.ago.strftime('%B %Y'), 'value' => 10, 'color' => '#C766EA', 'notMatchedValue' => 5,
            'invalidValue' => 0 },
          { 'label' => 1.month.ago.strftime('%B %Y'), 'value' => 3, 'color' => '#C766EA', 'notMatchedValue' => 5,
            'invalidValue' => 0 }
        ]
      )
    end

    it 'counts Invalid rows in the top-level population' do
      data = subject.find { |entry| entry['chart_id'] == bar_chart1.id }

      # 23 real rows + 4 Invalid. The frontend discards this value (`chartReducer.js` keeps only
      # `data`), but it is part of the API contract, so pin the new meaning rather than leave it
      # to drift.
      expect(data['population']).to eq(27)
    end
  end

  # SCOPE OF THESE EXAMPLES, stated honestly: they prove that the generator passes the relation it
  # is given straight through. All three examples pin `generate_hash` (including its `to_sql` + raw
  # `execute`) and `entry_count_hash`. The THIRD reader, `periodical_statistics`, is pinned only by
  # the label-list assertion in the last example: without it, a bare-class read at
  # `bar_chart.rb:72` would break no spec in this repository. They do NOT exercise `accessible_by`,
  # the `left_joins(:chart)` or the role composition that `charts_data_controller.rb:74-83` adds,
  # so they are not a substitute for request-level authorization coverage. That now exists:
  # `spec/requests/v1/organizations/charts_data/generate_charts_data_spec.rb` -> "when Invalid /
  # Insufficient Data rows exist across clinics and organizations" drives the real controller as a
  # `health_clinic_admin`, with Invalid rows planted on a sibling clinic and another organization.
  #
  # Nor can they fail for the reason the old `excluding_insufficient_data` spec guarded: that
  # scope's `Relation#or` was the hazard, and this phase deleted it. Removing an AND-ed predicate
  # is monotonic within the caller's relation. They are a tripwire against a future rewrite that
  # reintroduces filtering here on the bare class rather than on the passed relation.
  # Bands 2..n have no series on either bar type. `data_for_chart` reads `patterns.first` and
  # `default_pattern` and nothing else, so on a multi-case chart the participants who matched
  # the middle cases are drawn nowhere - while the top-level `population` still counts them.
  # Nothing pinned this before; the behaviour is load-bearing for any researcher who configures
  # severity bands, which is the ordinary way to use a chart formula.
  context 'when the chart formula defines more than one case' do
    let(:chart) { multi_band_chart }

    let!(:multi_band_chart) do
      create(:chart, name: 'severity', dashboard_section: dashboard_sections, chart_type: 'bar_chart', status: 'published',
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

    let(:datum) { subject.find { |entry| entry['chart_id'] == multi_band_chart.id }['data'].first }

    it 'draws only the first case, the default and Invalid' do
      expect(datum).to eq(
        'label' => 1.month.ago.strftime('%B %Y'),
        'value' => 3,
        'color' => '#C766EA',
        'notMatchedValue' => 2,
        'invalidValue' => 1
      )
    end

    it 'leaves the middle bands in no series at all, though population counts them' do
      chart_entry = subject.find { |entry| entry['chart_id'] == multi_band_chart.id }
      drawn = datum['value'] + datum['notMatchedValue'] + datum['invalidValue']

      expect(chart_entry['population']).to eq(15)
      expect(drawn).to eq(6)
      # 9 participants - every Moderate and every Mild - are counted but never drawn.
      expect(chart_entry['population'] - drawn).to eq(9)
    end
  end

  context "when the caller's relation is authorization-scoped" do
    let!(:other_organization) { create(:organization, name: 'Somebody Else') }
    let!(:other_health_system) { create(:health_system, organization: other_organization) }
    let!(:other_health_clinic) { create(:health_clinic, name: 'Other Clinic', health_system: other_health_system) }

    # Same chart, same period, but a different organization AND a different clinic - and Invalid,
    # which is precisely the label the removed predicate used to filter.
    let!(:foreign_invalid_statistics) do
      create_list(:chart_statistic, 7, label: ChartStatistic::INSUFFICIENT_DATA_LABEL, organization: other_organization,
                                       health_system: other_health_system, chart: bar_chart1,
                                       health_clinic: other_health_clinic, filled_at: 2.months.ago)
    end

    it "does not leak another organization's Invalid rows into the series" do
      scoped = described_class.new(ChartStatistic.where(organization_id: organization.id), charts).generate
      data = scoped.find { |entry| entry['chart_id'] == bar_chart1.id }
      period = data['data'].find { |datum| datum['label'] == 2.months.ago.strftime('%B %Y') }

      expect(period['invalidValue']).to eq(0)
      expect(period['value']).to eq(10)
      expect(data['population']).to eq(23)
    end

    it 'does not leak them into the clinic-scoped series either' do
      scoped = described_class.new(ChartStatistic.by_health_clinic_ids([health_clinic.id]), charts).generate
      data = scoped.find { |entry| entry['chart_id'] == bar_chart1.id }
      period = data['data'].find { |datum| datum['label'] == 2.months.ago.strftime('%B %Y') }

      expect(period['invalidValue']).to eq(0)
      expect(data['population']).to eq(23)
    end

    it 'counts them for a caller scoped to that other organization' do
      scoped = described_class.new(ChartStatistic.where(organization_id: other_organization.id), charts).generate
      data = scoped.find { |entry| entry['chart_id'] == bar_chart1.id }
      period = data['data'].find { |datum| datum['label'] == 2.months.ago.strftime('%B %Y') }

      # The tripwire for `periodical_statistics`: the span is derived from the INJECTED relation,
      # so a foreign-scoped caller sees exactly the one period its own rows fall in. A bare-class
      # read here would widen the axis to two periods and turn this assertion red.
      expect(data['data'].pluck('label')).to eq([2.months.ago.strftime('%B %Y')])
      expect(period['invalidValue']).to eq(7)
      expect(data['population']).to eq(7)
    end
  end

  context 'when chart has quarterly interval' do
    subject { described_class.new(data_collection, charts).generate }

    let!(:bar_chart1) do
      create(:chart, name: 'bar_chart1', dashboard_section: dashboard_sections, chart_type: 'bar_chart', status: 'published', interval_type: :quarterly)
    end
    let!(:bar_chart2) do
      create(:chart, name: 'bar_chart2', dashboard_section: dashboard_sections, chart_type: 'bar_chart', status: 'published', interval_type: :quarterly)
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
              'value' => 10,
              'color' => '#C766EA',
              'notMatchedValue' => 5,
              'invalidValue' => 0
            },
            {
              'label' => "Q#{(chart_matched_statistic2.first.filled_at.month / 3.0).ceil} #{chart_matched_statistic2.first.filled_at.year}",
              'value' => 3,
              'color' => '#C766EA',
              'notMatchedValue' => 5,
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
end
