# frozen_string_literal: true

namespace :reports do
  desc 'Mark all generated reports as downloaded in downloaded_reports model'
  task download: :environment do
    GeneratedReport.find_each do |report|
      case report.report_for
      when 'participant'
        participant_report_id = report.participant_id
        next if participant_report_id.nil?

        DownloadedReport.find_or_create_by!(
          user_id: participant_report_id,
          generated_report_id: report.id,
          downloaded: true
        )

      when 'third_party'
        GeneratedReportsThirdPartyUser.where(generated_report_id: report.id).each do |third_party_report|
          third_party_report_id = third_party_report.third_party_id
          next if third_party_report_id.nil?

          DownloadedReport.find_or_create_by!(
            user_id: third_party_report_id,
            generated_report_id: report.id,
            downloaded: true
          )
        end

      else
        next
      end
    end
  end
end
