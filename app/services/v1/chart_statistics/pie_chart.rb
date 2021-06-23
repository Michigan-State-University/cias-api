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
    data = {}
    data['label'] = label

    data['value'] = value
    current_pattern = patterns.find { |pattern| pattern['label'] == label }
    data['color'] = current_pattern.present? ? current_pattern['color'] : default_pattern['color']

    data
  end

  def current_chart_type_collection
    charts.where(chart_type: 'pie_chart', status: 'published')
  end

  def generate_hash
    Hash.new { |hash, chart_id| hash[chart_id] = Hash.new { |hash, label| hash[label] = 0 } }.tap do |hash|
      charts_data_collection.find_each { |data_statistic| hash[data_statistic.chart_id][data_statistic.label] += 1 }
    end
  end
end
