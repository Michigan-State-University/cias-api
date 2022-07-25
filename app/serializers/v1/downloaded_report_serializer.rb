# frozen_string_literal: true

class V1::DownloadedReportSerializer < V1Serializer
  attributes :user_id, :generated_report_id, :downloaded
end
