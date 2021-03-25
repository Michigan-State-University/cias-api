# frozen_string_literal: true

namespace :one_time_use do
  desc 'Enable sms notifications for all users'
  task enable_sms_notification_for_users: :environment do
    roles = %w[participant third_party researcher team_admin admin]
    User.limit_to_roles(roles).update_all(sms_notification: true)
  end
end
