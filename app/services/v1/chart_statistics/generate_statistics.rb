# frozen_string_literal: true

class V1::ChartStatistics::GenerateStatistics
  attr_reader :charts_data_collection, :charts, :date_offset

  def initialize(charts_data_collection, charts, date_offset = nil)
    @charts_data_collection = charts_data_collection
    @charts = charts
    @date_offset = date_offset
  end

  def generate_statistics
    percentage_bar_chart_statistics = V1::ChartStatistics::BarChart::Percentage.new(charts_data_collection, charts, date_offset).generate
    numeric_bar_chart_statistics = V1::ChartStatistics::BarChart::Numeric.new(charts_data_collection, charts, date_offset).generate
    pie_chart_statistics = V1::ChartStatistics::PieChart.new(charts_data_collection, charts).generate

    percentage_bar_chart_statistics + numeric_bar_chart_statistics + pie_chart_statistics
  end

  def generate_statistic_for_chart
    if charts.bar_chart?
      V1::ChartStatistics::BarChart::Numeric.new(charts_data_collection, charts, date_offset).generate
    elsif charts.pie_chart?
      V1::ChartStatistics::PieChart.new(charts_data_collection, charts).generate
    else
      V1::ChartStatistics::BarChart::Percentage.new(charts_data_collection, charts, date_offset).generate
    end
  end
end
