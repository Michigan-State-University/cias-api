# frozen_string_literal: true

class RegenerateChartsJob < ApplicationJob
  queue_as :default

  def perform(chart_ids, replace = true)
    V1::Charts::Regenerate.call(chart_ids, replace: replace)
  end
end
