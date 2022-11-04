# frozen_string_literal: true

class ChartStatistic < ApplicationRecord
  has_paper_trail
  belongs_to :organization
  belongs_to :health_system
  belongs_to :health_clinic
  belongs_to :user
  belongs_to :chart

  scope :filled_between, ->(date_range) { where(filled_at: date_range) }
  scope :by_health_clinic_ids, ->(clinic_ids) { where(health_clinic_id: clinic_ids) }
  scope :ordered_data_for_chart, ->(chart_id) { where(chart_id: chart_id).order(filled_at: :asc) }

  before_save :set_filled_at_date, if: -> { filled_at.nil? }

  private

  def set_filled_at_date
    self.filled_at = created_at
  end
end
