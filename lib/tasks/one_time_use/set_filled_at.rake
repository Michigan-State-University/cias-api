# frozen_string_literal: true

namespace :one_time_use do
  desc 'Set filled_at in chart statistics'
  task set_filled_at: :environment do
    ActiveRecord::Base.transaction do
      ChartStatistic.all.each do |chart_statistic|
        chart_statistic.update!(filled_at: chart_statistic.created_at) if chart_statistic.filled_at.nil?
      end
      p 'done!'
    end
  end
end
