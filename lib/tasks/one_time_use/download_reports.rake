# frozen_string_literal: true

namespace :one_time_use do
  desc 'Mark all generated reports as downloaded in downloaded_reports model'

  def mark_as_downloaded(user_id, generated_report_id)
    return unless User.find_by(id: user_id)

    DownloadedReport.find_or_create_by!(
      user_id: user_id,
      generated_report_id: generated_report_id
    )
  end

  task mark_reports_as_downloaded: :environment do
    index = 0
    users = User.limit_to_roles(%w[participant third_party researcher e_intervention_admin team_admin admin])
    users_count = users.count
    users.find_each do |user|
      GeneratedReport.accessible_by(user.ability).find_each do |report|
        mark_as_downloaded(user.id, report.id)
      end
      p "Marking as download for users #{index}/#{users_count}"
      index += 1
    end
    p "Rake done!"
  end
end
