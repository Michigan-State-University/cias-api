# frozen_string_literal: true

class V1::ChartSerializer < V1Serializer
  attributes :name, :description, :chart_type, :status, :formula, :trend_line, :dashboard_section_id,
             :published_at, :position, :interval_type, :date_range_start, :date_range_end

  # Read-only `M` — the number of variables the formula payload references.
  attribute :formula_variable_count
end
