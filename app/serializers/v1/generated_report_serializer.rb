# frozen_string_literal: true

class V1::GeneratedReportSerializer < V1Serializer
  attributes :name, :report_for

  attribute :pdf_report_url do |object|
    url_for(object.pdf_report) if object.pdf_report.attached?
  end

  attribute :created_at do |object|
    object.created_at.iso8601
  end
end
