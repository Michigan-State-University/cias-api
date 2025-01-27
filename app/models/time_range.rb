# frozen_string_literal: true

class TimeRange < ApplicationRecord
  validates :from, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 24 }
  validates :to, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 24 }

  enum :label, { early_morning: 'early_morning', mid_morning: 'mid_morning', afternoon: 'afternoon', early_evening: 'early_evening', night: 'night' }

  def self.default_range
    find_by(default: true)
  end
end
