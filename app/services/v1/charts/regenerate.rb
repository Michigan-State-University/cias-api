# frozen_string_literal: true

class V1::Charts::Regenerate
  def self.call(chart_ids, replace: true)
    new(chart_ids, replace: replace).call
  end

  def initialize(chart_ids, replace: true)
    @chart_ids = chart_ids
    @replace = replace
  end

  # The destroy happens per chart INSIDE CreateForUserSessions' lock. Destroying up front meant a
  # chart that was then skipped (locked) or that raised had its rows deleted and never rebuilt.
  def call
    chart_ids.each do |chart_id|
      V1::ChartStatistics::CreateForUserSessions.call(chart_id, replace: replace)
    end
  end

  private

  attr_reader :chart_ids, :replace
end
