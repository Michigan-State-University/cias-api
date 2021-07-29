# frozen_string_literal: true

class V1::ChartStatistics::BarChart::Percentage < V1::ChartStatistics::BarChart
  private

  def data_for_chart(month, value, patterns, default_pattern)
    pattern = patterns.first

    monthly_data_value = value[pattern['label']]

    other_label = default_pattern['label']
    population = value[other_label] + monthly_data_value
    monthly_data_value = population.zero? ? 0 : (monthly_data_value.to_f / population * 100).round(2)

    {
      'label' => month,
      'color' => pattern['color'],
      'population' => population,
      'value' => monthly_data_value
    }
  end

  def current_chart_type_collection
    charts.where(chart_type: 'percentage_bar_chart')
  end
end
