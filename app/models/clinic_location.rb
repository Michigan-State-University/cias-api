# frozen_string_literal: true

class ClinicLocation < ApplicationRecord
  has_paper_trail
  has_many :intervention_locations, dependent: :destroy
  has_many :interventions, through: :intervention_locations

  validates :department, :name, presence: true
end
