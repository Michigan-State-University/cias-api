class V1::Charts::Update
  def self.call(chart, chart_params)
    new(chart, chart_params).call
  end

  def initialize(chart, chart_params)
    @chart = chart
    @chart_params = chart_params
  end

  def call
    chart.assign_attributes(chart_params)
    chart.integral_update
    chart
  end

  private

  attr_reader :chart_params
  attr_accessor :chart

end
