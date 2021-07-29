# frozen_string_literal: true

class V1::ChartStatistics::BarChart::Numeric < V1::ChartStatistics::BarChart
  private

  def data_for_chart(month, value, patterns, default_pattern)
    pattern = patterns.first
    other_label = default_pattern['label']

    {
      'label' => month,
      'value' => value[pattern['label']],
      'color' => pattern['color'],
      'notMatchedValue' => value[other_label]
    }
  end

  def current_chart_type_collection
    charts.where(chart_type: 'bar_chart')
  end
end
