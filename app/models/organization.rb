# frozen_string_literal: true

class Organization < ApplicationRecord
  validates :name, presence: true

  default_scope { order(:name) }
end
