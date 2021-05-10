class V1::Charts::Create
  def self.call(chart_params)
    new(chart_params).call
  end

  def initialize(chart_params)
    @chart_params = chart_params
  end

  def call
    Chart.create!(chart_params)
  end

  private

  attr_reader :chart_params
end
