# frozen_string_literal: true

class CreateChartStatisticsJob < ApplicationJob
  queue_as :default

  def perform(chart_id)
    V1::Charts::ChartStatistics::Create.call(chart_id)
  end
end
