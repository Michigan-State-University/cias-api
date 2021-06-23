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
    chart_statistic = {}
    chart_statistic['chart_id'] = chart.id
    chart_statistic['data'] = statistics
    chart_statistic['population'] = charts_data_collection.where(chart_id: chart.id).count
    chart_statistic['dashboard_section_id'] = chart.dashboard_section_id
    chart_statistic
  end
end
