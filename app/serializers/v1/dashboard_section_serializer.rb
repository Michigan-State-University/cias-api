# frozen_string_literal: true

class V1::DashboardSectionSerializer < V1Serializer
  attributes :name, :description, :reporting_dashboard_id, :position

  has_many :charts, serializer: V1::ChartSerializer, if: proc { |_record, params| params[:only_published] != 'true' }

  attribute :charts, if: proc { |_record, params|
    params && params[:only_published] == 'true'
  } do |object|
    object.charts.where({ status: :published })
  end

  attribute :organization_id do |object|
    ReportingDashboard.find_by(id: object.reporting_dashboard_id)&.organization_id
  end
end
