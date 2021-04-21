# frozen_string_literal: true

class HealthSystem < ApplicationRecord
  belongs_to :organization
  has_many :health_clinics, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :organization }
end
