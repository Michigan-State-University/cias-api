# frozen_string_literal: true

namespace :one_time_use do
  desc 'Encrypt current body answers data'
  task encrypt_current_body_answers_data: :environment do
    Lockbox.migrate(Answer)
  end
end
