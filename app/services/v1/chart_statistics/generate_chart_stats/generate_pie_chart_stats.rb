# frozen_string_literal: true

class V1::ChartStatistics::GenerateChartStats::GeneratePieChartStats < V1::ChartStatistics::GenerateChartStats
  def initialize(charts_data_collection, charts)
    @charts_data_collection = charts_data_collection
    @charts = charts.where(chart_type: 'pie_chart', status: 'published')
  end

  private

  def chart_statistics(aggregated_data, chart)
    chart_statistic = {}
    patterns = chart.formula['patterns']
    default_pattern = chart.formula['default_pattern']

    statistics = aggregated_data.map do |label, value|
      data_for_chart(label, value, patterns, default_pattern)
    end

    add_basic_information(chart, chart_statistic, statistics)
  end

  def data_for_chart(label, value, patterns, default_pattern)
    data = {}
    data['label'] = label

    data['value'] = value
    current_pattern = patterns.find { |pattern| pattern['label'] == label }
    data['color'] = current_pattern.present? ? current_pattern['color'] : default_pattern['color']

    data
  end

  def generate_hash
    Hash.new { |hash, chart_id| hash[chart_id] = Hash.new { |hash, label| hash[label] = 0 } }.tap do |hash|
      charts_data_collection.find_each { |data_statistic| hash[data_statistic.chart_id][data_statistic.label] += 1 }
    end
  end
end
