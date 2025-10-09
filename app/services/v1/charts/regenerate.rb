# frozen_string_literal: true

class V1::Charts::Regenerate
  def self.call(chart_ids, replace: true)
    new(chart_ids, replace: replace).call
  end

  def initialize(chart_ids, replace: true)
    @chart_ids = chart_ids
    @replace = replace
  end

  def call
    ChartStatistic.where(chart_id: chart_ids).destroy_all if replace
    chart_ids.each do |chart_id|
      V1::ChartStatistics::CreateForUserSessions.call(chart_id, true)
    end
  end

  private

  attr_reader :chart_ids, :replace
end
