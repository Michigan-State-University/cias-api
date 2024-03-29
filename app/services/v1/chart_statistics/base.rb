# frozen_string_literal: true

class V1::ChartStatistics::Base
  attr_reader :charts_data_collection, :charts

  def initialize(charts_data_collection, charts)
    @charts_data_collection = charts_data_collection
    @charts = charts
  end

  def generate
    aggregated_data = generate_hash
    collection = charts.is_a?(Chart) ? [charts] : current_chart_type_collection

    collection.map do |chart|
      statistics = chart_statistics(aggregated_data[chart.id], chart)
      add_basic_information(chart, statistics)
    end
  end

  private

  def generate_hash
    raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
  end

  def chart_statistics(_aggregated_data, _chart)
    raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
  end

  def data_for_chart(_label, _value, _patterns, _default_pattern)
    raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
  end

  def current_chart_type_collection
    raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
  end

  def add_basic_information(chart, statistics)
    {
      'chart_id' => chart.id,
      'data' => statistics,
      'population' => entry_count_hash[chart.id] || 0,
      'dashboard_section_id' => chart.dashboard_section_id
    }
  end

  def entry_count_hash
    @entry_count_hash ||= charts_data_collection.group(:chart_id).count
  end
end
