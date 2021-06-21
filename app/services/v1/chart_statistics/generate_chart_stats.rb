# frozen_string_literal: true

class V1::ChartStatistics::GenerateChartStats
  attr_reader :charts_data_collection, :charts

  def initialize(charts_data_collection, charts)
    @charts_data_collection = charts_data_collection
    @charts = charts
  end

  def generate
    raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
  end

  def generate_hash
    raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
  end

  def add_basic_information(chart, chart_statistic, statistics)
    chart_statistic['chart_id'] = chart.id
    chart_statistic['data'] = statistics
    chart_statistic['population'] = charts_data_collection.where(chart_id: chart.id).count
    chart_statistic['dashboard_section_id'] = chart.dashboard_section_id
    chart_statistic
  end
end
