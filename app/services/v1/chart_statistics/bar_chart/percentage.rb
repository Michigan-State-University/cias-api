# frozen_string_literal: true

class V1::ChartStatistics::BarChart::Percentage < V1::ChartStatistics::BarChart
  private

  # Invalid participants count toward the DENOMINATOR but get no series of their own: this chart
  # renders a single bar of `% matched` against a [0,100] axis, and `invalidValue` is carried for
  # the hover text only. So `value` now means "% matched of everyone who reached the gate", and it
  # is lower than it used to be wherever anyone fell below the minimum.
  #
  # `population` is deliberately `matched + notMatched + invalid` rather than every row in the
  # period: `patterns.first` is still the only case rendered, so bands 2..n belong to no series
  # and counting them would make the bar a percentage of something it does not draw.
  #
  # No largest-remainder rounding is needed - with a single series there is no residue to
  # distribute, so the historical `.round(2)` stands.
  def data_for_chart(month, value, patterns, default_pattern)
    pattern = patterns.first

    monthly_data_value = value[pattern['label']]

    other_label = default_pattern['label']
    invalid_value = value[ChartStatistic::INSUFFICIENT_DATA_LABEL]
    population = value[other_label] + monthly_data_value + invalid_value
    monthly_data_value = population.zero? ? 0 : (monthly_data_value.to_f / population * 100).round(2)

    {
      'label' => month,
      'color' => pattern['color'],
      'population' => population,
      'value' => monthly_data_value,
      'invalidValue' => invalid_value
    }
  end

  def current_chart_type_collection
    charts.where(chart_type: 'percentage_bar_chart')
  end
end
