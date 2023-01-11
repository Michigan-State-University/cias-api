# frozen_string_literal: true

class InterventionAccess < ApplicationRecord
  belongs_to :intervention

  validates :email, presence: true
end
