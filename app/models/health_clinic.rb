# frozen_string_literal: true

class HealthClinic < ApplicationRecord
  belongs_to :health_system

  validates :name, presence: true, uniqueness: { scope: :health_system }

  scope :clinics_in_health_system, ->(health_system_id) { HealthClinic.where(health_system_id: health_system_id) }
end
