# frozen_string_literal: true

class V1::HealthClinics::Destroy
  def self.call(health_clinic)
    new(health_clinic).call
  end

  def initialize(health_clinic)
    @health_clinic = health_clinic
  end

  def call
    ActiveRecord::Base.transaction do
      cancel_user_invitations(health_clinic)
      health_clinic.destroy!
    end
  end

  private

  attr_accessor :health_clinic

  def cancel_user_invitations(health_clinic)
    User.where(organizable_id: health_clinic.id, active: false, confirmed_at: nil).delete_all
  end
end
