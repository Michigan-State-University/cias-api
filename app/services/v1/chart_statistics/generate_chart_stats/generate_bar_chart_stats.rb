# frozen_string_literal: true

class V1::ChartStatistics::GenerateChartStats::GenerateBarChartStats < V1::ChartStatistics::GenerateChartStats
  attr_reader :data_offset

  def initialize(charts_data_collection, charts, data_offset = nil)
    @charts_data_collection = charts_data_collection
    @charts = charts
    @data_offset = data_offset
  end

  def chart_statistics(aggregated_data, chart)
    chart_statistic = {}

    patterns = chart.formula['patterns']
    default_pattern = chart.formula['default_pattern']

    statistics = monthly_statistics(aggregated_data, patterns, default_pattern)

    add_basic_information(chart, chart_statistic, statistics)
  end

  def generate_hash
    Hash.new { |hash, chart_id| hash[chart_id] = Hash.new { |hash, date| hash[date] = Hash.new { |hash, label| hash[label] = 0 } } }.tap do |hash|
      charts_data_collection.find_each do |data_statistic|
        hash[data_statistic.chart_id][data_statistic.created_at.strftime('%B %Y')][data_statistic.label] += 1
      end
    end
  end

  def monthly_statistics(aggregated_data, patterns, default_pattern)
    statistics = []
    if data_offset.present?
      current_month = Time.current - data_offset.to_i.days
      current_month = current_month.beginning_of_month
    else
      current_month = first_month(aggregated_data)
    end

    return [] if current_month.nil?

    current_month = current_month.to_date

    while current_month <= Time.current.beginning_of_month
      month = current_month.strftime('%B %Y')
      value = aggregated_data[month]
      statistics << data_for_chart(month, value, patterns, default_pattern)

      current_month = current_month.next_month
    end
    statistics
  end

  def first_month(aggregated_data)
    first = nil
    aggregated_data.each do |month, _value|
      first = month if first.nil?

      first = month if first.to_date > month.to_date
    end

    first
  end
end
