# frozen_string_literal: true

class V1::DashboardSectionSerializer < V1Serializer
  attributes :name, :description, :reporting_dashboard_id

  has_many :charts, serializer: V1::ChartSerializer
end
