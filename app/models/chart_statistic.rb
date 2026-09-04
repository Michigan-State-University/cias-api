# frozen_string_literal: true

class ChartStatistic < ApplicationRecord
  # Reserved label for a participant who reached a gated chart's validity gate but neither
  # passed the "N out of M answered variables" minimum nor matched an explicit case: they
  # stay VISIBLE as their own category instead of being silently dropped (CIAS-4191).
  #
  # Stored verbatim, in English, on purpose. Chart labels are researcher-authored strings
  # persisted on the row and rendered verbatim on both the editor tile and the published
  # dashboard - there is no i18n layer for chart labels anywhere - so the reserved label
  # follows the same convention. Renaming it later is a data migration, and `Chart`
  # rejects any pattern/default label that collides with it (case-insensitively).
  INSUFFICIENT_DATA_LABEL = 'Invalid / Insufficient Data'

  has_paper_trail
  belongs_to :organization
  belongs_to :health_system
  belongs_to :health_clinic
  belongs_to :user
  belongs_to :user_session
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
