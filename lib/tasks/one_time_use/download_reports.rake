# frozen_string_literal: true

namespace :one_time_use do
  desc 'Mark all generated reports as downloaded in downloaded_reports model'

  def mark_as_downloaded(user_id, generated_report_id)
    DownloadedReport.find_or_create_by!(
      user_id: user_id,
      generated_report_id: generated_report_id
    )
  end

  task mark_reports_as_downloaded: :environment do
    GeneratedReport.find_each do |report|
      case report.report_for
      when 'participant'
        mark_as_downloaded(report.participant_id, report.id)

      when 'third_party'
        GeneratedReportsThirdPartyUser.where(generated_report_id: report.id).find_each do |third_party_report|
          mark_as_downloaded(third_party_report.third_party_id, report.id)
        end

      else
        next
      end
    end
  end
end
