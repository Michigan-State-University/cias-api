# frozen_string_literal: true

class V1::ChartStatistics::GenerateChartStats::GeneratePercentageBarChartStats < V1::ChartStatistics::GenerateChartStats
  def generate
    aggregated_data = generate_hash
    bar_charts = charts.where(chart_type: 'percentage_bar_chart', status: 'published')

    bar_charts.map do |chart|
      percentage_bar_chart_statistics(aggregated_data[chart.id], chart)
    end
  end

  def generate_for_chart
    chart = charts

    return unless chart.published?

    aggregated_data = generate_hash
    percentage_bar_chart_statistics(aggregated_data[chart.id], chart)
  end

  def percentage_bar_chart_statistics(aggregated_data, chart)
    chart_statistic = {}

    patterns = chart.formula['patterns']
    default_pattern = chart.formula['default_pattern']

    statistics = aggregated_data.map do |month, value|
      monthly_data_for_char(month, value, patterns, default_pattern)
    end
    statistics = statistics.sort_by { |statistic| statistic['label'].to_time }

    add_basic_information(chart, chart_statistic, statistics)
  end

  def monthly_data_for_char(date, values, patterns, default_pattern)
    monthly_data = {}
    monthly_data['label'] = date

    patterns.each do |pattern|
      monthly_data['value'] = values[pattern['label']]
      monthly_data['color'] = pattern['color']
    end

    other_label = default_pattern['label']
    monthly_data['population'] = values[other_label] + monthly_data['value']
    monthly_data['value'] = (monthly_data['value'].to_f / monthly_data['population'] * 100).round(2)

    monthly_data
  end

  def generate_hash
    Hash.new { |hash, chart_id| hash[chart_id] = Hash.new { |hash, date| hash[date] = Hash.new { |hash, label| hash[label] = 0 } } }.tap do |hash|
      charts_data_collection.find_each do |data_statistic|
        hash[data_statistic.chart_id][data_statistic.created_at.strftime('%B %Y')][data_statistic.label] += 1
      end
    end
  end
end
