# frozen_string_literal: true

class V1::ChartStatistics::GenerateStatistics
  attr_reader :charts_data_collection

  def initialize(charts_data_collection)
    @charts_data_collection = charts_data_collection
  end

  def generate_bar_chart_statistics
    aggregated_data = generate_bar_chart_hash

    chart_data_table = []
    aggregated_data.each do |key, value|
      chart_hash = {}
      chart_hash['chart_id'] = key
      chart_hash['chart_data'] = []

      value.each do |date, value|
        chart_hash['chart_data'].append(hash_item_to_bar_chart(date, value))
      end

      chart_data_table.append(chart_hash)
    end

    chart_data_table
  end

  def generate_pie_chart_statistics
    aggregated_data = generate_pie_chart_hash

    chart_data_table = []
    aggregated_data.each do |chart_id, value|
      chart_hash = {}
      chart_hash['chart_id'] = chart_id
      chart_hash['chart_data'] = []

      value.each do |label, value|
        chart_hash['chart_data'].append(hash_item_to_pie_chart(label, value))
      end
      chart_data_table.append(chart_hash)
    end

    chart_data_table
  end

  private

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

  def hash_item_to_bar_chart(date, value)
    item = {}
    item['date'] = date
    statistics = []
    value.each do |label, value|
      statistic = {}
      statistic['label'] = label
      statistic['value'] = value
      statistics.append(statistic)
    end
    item['data'] = statistics
    item
  end

  def hash_item_to_pie_chart(label, value)
    item = {}
    item['label'] = label
    item['value'] = value
    item
  end
end
