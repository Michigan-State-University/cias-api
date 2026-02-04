# frozen_string_literal: true

class TagIntervention < ApplicationRecord
  belongs_to :tag
  belongs_to :intervention
end
