# frozen_string_literal: true

class Star < ApplicationRecord
  has_paper_trail
  belongs_to :user, inverse_of: :stars
  belongs_to :intervention, inverse_of: :stars

  validates :user_id, uniqueness: { scope: :intervention_id }
end
