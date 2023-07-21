# frozen_string_literal: true

class InterventionLocation < ApplicationRecord
  has_paper_trail
  belongs_to :intervention
  belongs_to :clinic_location
end
