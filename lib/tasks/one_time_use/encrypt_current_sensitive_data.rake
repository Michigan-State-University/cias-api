# frozen_string_literal: true

namespace :one_time_use do
  desc 'Encrypt current sensitive data of users'
  task encrypt_current_sensitive_data: :environment do
    Lockbox.migrate(User)
    Lockbox.migrate(Phone)
    Lockbox.migrate(Message)
    Lockbox.migrate(Invitation)
  end
end
