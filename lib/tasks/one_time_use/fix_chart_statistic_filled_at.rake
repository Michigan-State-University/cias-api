# frozen_string_literal: true

namespace :one_time_use do
  desc 'Fix chart statistic filled at '
  task fix_chart_statistic_filled_at: :environment do
    chart_statistics = ChartStatistic.where(filled_at: nil)
    chart_statistics_count = chart_statistics.count
    organization_ids = Set.new()
    chart_statistics.each_with_index { |chart_statistic, index|
      chart_statistic.update!(filled_at: chart_statistic.created_at)
      p "Fixing ChartStatistic filled at #{index + 1}/#{chart_statistics_count} for organization #{chart_statistic.organization.name}"
      organization_ids.add(chart_statistic.organization.id)
    }
    p "Fixing done"
    p "=========="
    p "Urls of organizations with invalid data"
    organization_ids.each{|organization_id|
      p "#{ENV['WEB_URL']}/organization/#{organization_id}/dashboard"
    }
    p "=========="
  end
end
