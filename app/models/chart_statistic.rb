# frozen_string_literal: true

class ChartStatistic < ApplicationRecord
  has_paper_trail
  belongs_to :organization
  belongs_to :health_system
  belongs_to :health_clinic
  belongs_to :user
  belongs_to :chart

  scope :created_between, ->(date_range) { where(created_at: date_range) }
  scope :by_health_clinic_ids, ->(clinic_ids) { where(health_clinic_id: clinic_ids) }
end
