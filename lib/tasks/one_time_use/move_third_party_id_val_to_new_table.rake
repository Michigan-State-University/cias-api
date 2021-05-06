# frozen_string_literal: true

namespace :one_time_use do
  desc "We will remove third_party_id field from generated_reports,
        so we move the value of these field to generated_reports_third_party_users table"
  task move_third_party_id_to_new_table: :environment do
    GeneratedReport.all.each do |report|
      next unless report.third_party_id

      report.generated_reports_third_party_users.create!(third_party_id: report.third_party_id)
    end
  end
end
