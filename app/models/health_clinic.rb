# frozen_string_literal: true

class HealthClinic < ApplicationRecord
  belongs_to :health_system

  validates :name, presence: true, uniqueness: { scope: :health_system }
end
