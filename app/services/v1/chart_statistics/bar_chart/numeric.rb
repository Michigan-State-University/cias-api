# frozen_string_literal: true

class V1::ChartStatistics::BarChart::Numeric < V1::ChartStatistics::BarChart
  private

  # Three-valued: the matched pattern, the default label, and the reserved
  # `Invalid / Insufficient Data` label, which will render as a third stacked segment.
  # `invalidValue` is the ONLY new datum key - the colour is not shipped per datum: Recharts takes
  # `fill` per `<Bar>` series, and `cias-web` already holds the same grey as `colors.heather`.
  def data_for_chart(month, value, patterns, default_pattern)
    pattern = patterns.first
    other_label = default_pattern['label']

    {
      'label' => month,
      'value' => value[pattern['label']],
      'color' => pattern['color'],
      'notMatchedValue' => value[other_label],
      'invalidValue' => value[ChartStatistic::INSUFFICIENT_DATA_LABEL]
    }
  end

  def current_chart_type_collection
    charts.where(chart_type: 'bar_chart')
  end
end
