# frozen_string_literal: true

class V1::ChartStatistics::BarChart::Numeric < V1::ChartStatistics::BarChart
  private

  def data_for_chart(month, value, patterns, default_pattern)
    monthly_data = {}
    pattern = patterns.first

    monthly_data['label'] = month

    monthly_data['value'] = value[pattern['label']]
    monthly_data['color'] = pattern['color']

    other_label = default_pattern['label']
    monthly_data['notMatchedValue'] = value[other_label]
    monthly_data
  end

  def current_chart_type_collection
    charts.where(chart_type: 'bar_chart')
  end
end
