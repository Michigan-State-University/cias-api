# frozen_string_literal: true

class V1::ChartStatistics::RegenerateForAllOrganizations
  attr_reader :replace, :batch_size

  def self.call(replace: true, batch_size: 30)
    new(replace, batch_size).call
  end

  def initialize(replace = true, batch_size = 30)
    @replace = replace
    @batch_size = batch_size
  end

  def call
    Organization.find_each do |organization|
      regenerate_for_organization(organization)
    end
  end

  private

  def regenerate_for_organization(organization)
    chart_ids = organization.charts.where(status: %w[data_collection published]).pluck(:id)

    return if chart_ids.empty?

    if chart_ids.size > batch_size
      chart_ids.each_slice(batch_size) do |batch_ids|
        RegenerateChartsJob.perform_later(batch_ids, replace)
      end
    else
      RegenerateChartsJob.perform_later(chart_ids, replace)
    end
  end
end
