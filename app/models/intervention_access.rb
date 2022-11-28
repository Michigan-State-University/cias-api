# frozen_string_literal: true

class InterventionAccess < ApplicationRecord
  CURRENT_VERSION = '1'

  belongs_to :intervention

  validates :email, presence: true
end
