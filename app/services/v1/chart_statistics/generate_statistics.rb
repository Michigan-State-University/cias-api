# frozen_string_literal: true

class V1::ChartStatistics::GenerateStatistics
  attr_reader :charts_data_collection, :charts

  def initialize(charts_data_collection, charts)
    @charts_data_collection = charts_data_collection
    @charts = charts
  end

  def generate_statistics

    percentage_bar_chart_statistics = generate_percentage_bar_chart_statistics
    numeric_bar_chart_statistics = generate_numeric_bar_chart_statistics
    pie_chart_statistics = generate_pie_chart_statistics

    percentage_bar_chart_statistics + numeric_bar_chart_statistics + pie_chart_statistics
  end

  private

  def generate_percentage_bar_chart_statistics
    aggregated_data = generate_bar_chart_hash
    bar_charts = charts.where(chart_type: 'percentage_bar_chart')
    charts_statistic = []

    bar_charts.each do |chart|
      charts_statistic << percentage_bar_chart_statistics(aggregated_data[chart.id], chart)
    end

    charts_statistic
  end

  def generate_numeric_bar_chart_statistics
    aggregated_data = generate_bar_chart_hash
    bar_charts = charts.where(chart_type: 'bar_chart')
    charts_statistic = []

    bar_charts.each do |chart|
      charts_statistic << numeric_bar_chart_statistics(aggregated_data[chart.id], chart)
    end

    charts_statistic
  end

  def generate_pie_chart_statistics
    aggregated_data = generate_pie_chart_hash
    pie_charts = charts.where(chart_type: 'pie_chart')

    charts_statistic = []

    pie_charts.each do |chart|
      charts_statistic << numeric_pie_chart_statistics(aggregated_data[chart.id], chart)
    end

    charts_statistic
  end

  def numeric_pie_chart_statistics(aggregated_data, chart)
    chart_statistic = {}
    statistics = []
    patterns = chart.formula['patterns']
    default_pattern = chart.formula['default_pattern']

    aggregated_data.each do |label, value|
      statistics << data_for_pie_chart(label, value, patterns, default_pattern)
    end

    add_basic_information(chart, chart_statistic, statistics)
    chart_statistic
  end

  def data_for_pie_chart(label, value, patterns, default_pattern)
    data = {}
    data['label'] = label

    data['value'] = value
    current_pattern = patterns.find { |pattern| pattern['label'] == label }
    if current_pattern.present?
      data['color'] = current_pattern['color']
    else
      data['color'] = default_pattern['color']
    end
    data
  end

  def numeric_bar_chart_statistics(aggregated_data, chart)
    chart_statistic = {}
    statistics = []

    patterns = chart.formula['patterns']
    default_pattern = chart.formula['default_pattern']

    aggregated_data.each do |month, value|
      statistics << monthly_data_for_numeric_bar_chart(month, value, patterns, default_pattern)
    end

    add_basic_information(chart, chart_statistic, statistics)
    chart_statistic
  end

  def monthly_data_for_numeric_bar_chart(month, value, patterns, default_pattern)
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

  def percentage_bar_chart_statistics(aggregated_data, chart)
    statistics = []
    chart_statistic = {}
    patterns = chart.formula['patterns']
    default_pattern = chart.formula['default_pattern']

    aggregated_data.each do |month, values|
      statistics << monthly_data_for_percentage_bar_char(month, values, patterns, default_pattern)
    end

    add_basic_information(chart, chart_statistic, statistics)
    chart_statistic
  end

  def add_basic_information(chart, chart_statistic, statistics)
    chart_statistic['chart_id'] = chart.id
    chart_statistic['data'] = statistics
    chart_statistic['population'] = charts_data_collection.where(chart_id: chart.id).count
    chart_statistic['dashboard_section_id'] = chart.dashboard_section_id
  end

  def monthly_data_for_percentage_bar_char(date, values, patterns, default_pattern)
    monthly_data = {}
    monthly_data['label'] = date

    patterns.each do |pattern|
      monthly_data['value'] = values[pattern['label']]
      monthly_data['color'] = pattern['color']
    end

    other_label = default_pattern['label']
    monthly_data['population'] = values[other_label] + monthly_data['value']
    monthly_data['value'] = monthly_data['value'].to_f / monthly_data['population']
    monthly_data
  end

  def generate_bar_chart_hash
    Hash.new { |hash, chart_id| hash[chart_id] = Hash.new { |hash, date| hash[date] = Hash.new { |hash, label| hash[label] = 0 } } }.tap do |hash|
      charts_data_collection.find_each do |data_statistic|
        hash[data_statistic.chart_id][data_statistic.created_at.strftime('%B %Y')][data_statistic.label] += 1
      end
    end
  end

  def generate_pie_chart_hash
    Hash.new { |hash, chart_id| hash[chart_id] = Hash.new { |hash, label| hash[label] = 0 } }.tap do |hash|
      charts_data_collection.find_each { |data_statistic| hash[data_statistic.chart_id][data_statistic.label] += 1 }
    end
  end
end
