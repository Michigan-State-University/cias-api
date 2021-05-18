# frozen_string_literal: true

class V1::ChartSerializer < V1Serializer
  attributes :name, :description, :chart_type, :status, :formula, :dashboard_section_id, :published_at
end
