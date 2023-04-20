# frozen_string_literal: true

class TimeRange < ApplicationRecord
  validates :from, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 24 }
  validates :to, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 24 }
end
