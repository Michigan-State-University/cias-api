# frozen_string_literal: true

class V1::ChartStatistics::GenerateStatistics
  attr_reader :charts_data_collection, :charts, :date_offset

  def initialize(charts_data_collection, charts, date_offset = nil)
    @charts_data_collection = charts_data_collection
    @charts = charts
    @date_offset = date_offset
  end

  def generate_statistics
    pie_charts = charts.pie_chart
    percentage_bar_charts = charts.percentage_bar_chart
    numeric_bar_charts = charts.bar_chart

    percentage_bar_chart_statistics = if percentage_bar_charts.any?
                                        V1::ChartStatistics::BarChart::Percentage.new(charts_data_collection, percentage_bar_charts, date_offset).generate
                                      else
                                        []
                                      end

    numeric_bar_chart_statistics = if numeric_bar_charts.any?
                                     V1::ChartStatistics::BarChart::Numeric.new(charts_data_collection, numeric_bar_charts, date_offset).generate
                                   else
                                     []
                                   end

    pie_chart_statistics = if pie_charts.any?
                             V1::ChartStatistics::PieChart.new(charts_data_collection, pie_charts).generate
                           else
                             []
                           end

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
