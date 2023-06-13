# frozen_string_literal: true

class V1::CsvSerializer < V1Serializer
  attribute :link do |object|
    newest_csv_link(object) if object.reports.attached?
  end

  attribute :generated_at do |object|
    object.newest_report.created_at if object.reports.attached?
  end

  def self.newest_csv_link(object)
    ENV['APP_HOSTNAME'] + Rails.application.routes.url_helpers.rails_blob_path(object.newest_report, only_path: true)
  end
end
