# frozen_string_literal: true

class V1::Charts::Create
  def self.call(chart_params)
    new(chart_params).call
  end

  def initialize(chart_params)
    @chart_params = chart_params
    @chart_params[:position] = next_position
  end

  def call
    Chart.create!(chart_params)
  end

  private

  def next_position
    Chart.where(dashboard_section_id: @chart_params[:dashboard_section_id]).maximum(:position)&.next || 1
  end

  attr_reader :chart_params
end
