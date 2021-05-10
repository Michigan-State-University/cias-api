class V1::Charts::Destroy
  def self.call(chart)
    new(chart).call
  end

  def initialize(chart)
    @chart = chart
  end

  def call
    chart.destroy!
  end

  private

  attr_accessor :chart

end
