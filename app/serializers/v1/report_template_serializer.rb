# frozen_string_literal: true

class V1::ReportTemplateSerializer < V1Serializer
  attributes :name, :report_for, :logo_url, :summary, :session_id

  attribute :logo_url do |object|
    url_for(object.logo) if object.logo.attached?
  end
end
