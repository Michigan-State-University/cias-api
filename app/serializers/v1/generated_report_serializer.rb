# frozen_string_literal: true

class V1::GeneratedReportSerializer < V1Serializer
  attributes :name, :report_for

  attribute :pdf_report_url do |object|
    url_for(object.pdf_report) if object.pdf_report.attached?
  end

  attribute :created_at do |object|
    object.created_at.iso8601
  end

  attribute :downloaded do |object, params|
    report = DownloadedReport.find_by(user_id: params[:user], generated_report_id: object.id)
    report.nil? ? false : report.downloaded?
  end
end
