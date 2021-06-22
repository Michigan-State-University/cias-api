# frozen_string_literal: true

class V1::ChartStatistics::GenerateChartStats::GenerateBarChartStats < V1::ChartStatistics::GenerateChartStats
  def chart_statistics(aggregated_data, chart)
    chart_statistic = {}

    patterns = chart.formula['patterns']
    default_pattern = chart.formula['default_pattern']

    statistics = aggregated_data.map do |month, value|
      data_for_chart(month, value, patterns, default_pattern)
    end
    statistics = statistics.sort_by { |statistic| statistic['label'].to_time }

    add_basic_information(chart, chart_statistic, statistics)
  end

  def generate_hash
    Hash.new { |hash, chart_id| hash[chart_id] = Hash.new { |hash, date| hash[date] = Hash.new { |hash, label| hash[label] = 0 } } }.tap do |hash|
      charts_data_collection.find_each do |data_statistic|
        hash[data_statistic.chart_id][data_statistic.created_at.strftime('%B %Y')][data_statistic.label] += 1
      end
    end
  end
end
