# frozen_string_literal: true

class V1::Charts::Update
  def self.call(chart, chart_params)
    new(chart, chart_params).call
  end

  def initialize(chart, chart_params)
    @chart = chart
    @chart_params = chart_params
  end

  def call
    chart.integral_update(chart_params)
    chart
  end

  private

  attr_reader :chart_params
  attr_accessor :chart
end
