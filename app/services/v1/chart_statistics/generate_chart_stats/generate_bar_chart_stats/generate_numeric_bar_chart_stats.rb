# frozen_string_literal: true

class V1::ChartStatistics::GenerateChartStats::GenerateBarChartStats::GenerateNumericBarChartStats < V1::ChartStatistics::GenerateChartStats::GenerateBarChartStats
  private

  def data_for_chart(month, value, patterns, default_pattern)
    monthly_data = {}
    monthly_data['label'] = month

    patterns.each do |pattern|
      monthly_data['value'] = value[pattern['label']]
      monthly_data['color'] = pattern['color']
    end

    other_label = default_pattern['label']
    monthly_data['notMatchedValue'] = value[other_label]
    monthly_data
  end

  def current_chart_type_collection
    charts.where(chart_type: 'bar_chart', status: 'published')
  end
end
