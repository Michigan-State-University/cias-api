# frozen_string_literal: true

class RegenerateChartsJob < ApplicationJob
  queue_as :default

  def perform(replace = true)
    V1::Charts::Regenerate.call(all_chart_ids, replace: replace)
  end

  private

  def all_chart_ids
    Chart.where(status: %w[data_collection published]).pluck(:id)
  end
end
