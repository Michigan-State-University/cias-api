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

  # The slice color the pie aggregation stamps on the reserved label (cias-web
  # `colors.heather`) - a neutral grey absent from the color picker's 14 preset swatches.
  # Uniqueness cannot be guaranteed (the picker also takes a free hex value), so the grey
  # is a convention; the label collision guard on `Chart` is the real separator.
  INSUFFICIENT_DATA_COLOR = '#BDC7D6'

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
  # Bar and percentage-bar charts stay invalid-free (their series are two-valued by design).
  # NULL-safe deliberately: a bare `where.not(label: ...)` would ALSO drop rows whose label
  # is NULL (in SQL `NULL <> 'x'` is NULL, not true), and a NULL label is reachable - a
  # pattern with no `label` key is schema-valid, since db/schema/chart/formula.json
  # constrains no pattern item. Such rows must keep counting exactly as they do today.
  scope :excluding_insufficient_data, -> { where.not(label: INSUFFICIENT_DATA_LABEL).or(where(label: nil)) }

  before_save :set_filled_at_date, if: -> { filled_at.nil? }

  private

  def set_filled_at_date
    self.filled_at = created_at
  end
end
