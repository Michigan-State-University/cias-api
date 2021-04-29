class V1::HealthClinic::Create
  def self.call(health_clinic_params)
    new(health_clinic_params).call
  end

  def initialize(health_clinic_params)
    @health_clinic_params = health_system_params
  end

  def call
    HealthClinic.create!(name: health_clinic_params[:name])
  end

  attr_reader :health_clinic_params
end
