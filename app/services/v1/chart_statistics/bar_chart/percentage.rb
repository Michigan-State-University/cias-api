# frozen_string_literal: true

class V1::ChartStatistics::BarChart::Percentage < V1::ChartStatistics::BarChart
  private

  def data_for_chart(month, value, patterns, default_pattern)
    monthly_data = {}
    pattern = patterns.first
    monthly_data['label'] = month

    monthly_data['value'] = value[pattern['label']]
    monthly_data['color'] = pattern['color']

    other_label = default_pattern['label']
    monthly_data['population'] = value[other_label] + monthly_data['value']
    monthly_data['value'] = (monthly_data['population']).zero? ? 0 : (monthly_data['value'].to_f / monthly_data['population'] * 100).round(2)

    monthly_data
  end

  def current_chart_type_collection
    charts.where(chart_type: 'percentage_bar_chart', status: 'published')
  end
end
