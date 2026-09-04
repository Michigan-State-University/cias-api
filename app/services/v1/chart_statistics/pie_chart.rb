# frozen_string_literal: true

class V1::ChartStatistics::PieChart < V1::ChartStatistics::Base
  private

  def chart_statistics(aggregated_data, chart)
    patterns = chart.formula['patterns']
    default_pattern = chart.formula['default_pattern']

    aggregated_data.map do |label, value|
      data_for_chart(label, value, patterns, default_pattern)
    end
  end

  def data_for_chart(label, value, patterns, default_pattern)
    {
      'label' => label,
      'value' => value,
      'color' => color_for(label, patterns, default_pattern)
    }
  end

  # The pie keeps every row - the "Invalid / Insufficient Data" slice IS its data - but the
  # reserved label matches no pattern, so without this special case it would fall through
  # to `default_pattern['color']` and wear the default category's color. The frontend
  # colors each slice straight from `dataItem.color` (PieChart.js:35, passed through
  # untouched), so the fixed grey rides this datum and needs no frontend change.
  def color_for(label, patterns, default_pattern)
    return ChartStatistic::INSUFFICIENT_DATA_COLOR if label == ChartStatistic::INSUFFICIENT_DATA_LABEL

    current_pattern = patterns.find { |pattern| pattern['label'] == label }

    current_pattern.present? ? current_pattern['color'] : default_pattern['color']
  end

  def current_chart_type_collection
    charts.where(chart_type: 'pie_chart')
  end

  def generate_hash
    Hash.new { |hash, chart_id| hash[chart_id] = Hash.new { |hash, label| hash[label] = 0 } }.tap do |hash|
      statistics = charts_data_collection.group(:chart_id, :label).pluck('chart_statistics.chart_id, chart_statistics.label, COUNT(chart_statistics.label)')
      statistics.each { |data_statistic| hash[data_statistic[0]][data_statistic[1]] = data_statistic[2] }
    end
  end
  # rubocop:enable Lint/ShadowingOuterLocalVariable
end
