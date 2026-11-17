# frozen_string_literal: true

class CreateChartStatisticsJob < ApplicationJob
  include ChartRegenerationLockManagement

  queue_as :default

  def perform(chart_id)
    V1::ChartStatistics::CreateForUserSessions.call(chart_id)
  end

  def chart_ids_for_lock_cleanup
    Array(arguments.first)
  end
end
