# frozen_string_literal: true

class V1::ChartStatistics::GenerateStatistics
  attr_reader :charts_data_collection, :charts

  def initialize(charts_data_collection, charts)
    @charts_data_collection = charts_data_collection
    @charts = charts
  end

  def generate_statistics
    percentage_bar_chart_statistics = V1::ChartStatistics::GenerateChartStats::GeneratePercentageBarChartStats.new(charts_data_collection, charts).generate
    numeric_bar_chart_statistics = V1::ChartStatistics::GenerateChartStats::GenerateNumericBarChartStats.new(charts_data_collection, charts).generate
    pie_chart_statistics = V1::ChartStatistics::GenerateChartStats::GeneratePieChartStats.new(charts_data_collection, charts).generate

    percentage_bar_chart_statistics + numeric_bar_chart_statistics + pie_chart_statistics
  end

  def generate_statistic_for_chart
    if charts.bar_chart?
      V1::ChartStatistics::GenerateChartStats::GenerateNumericBarChartStats.new(charts_data_collection, charts).generate_for_chart
    elsif charts.pie_chart?
      V1::ChartStatistics::GenerateChartStats::GeneratePieChartStats.new(charts_data_collection, charts).generate_for_chart
    else
      V1::ChartStatistics::GenerateChartStats::GeneratePercentageBarChartStats.new(charts_data_collection, charts).generate_for_chart
    end
  end
end
