# frozen_string_literal: true

namespace :one_time_use do
  desc 'Set default values of session variables'
  task set_default_values_session_variables: :environment do
    Session.all.each do |session|
      variable = "session_#{session.position}"
      session.update!(variable: variable)
    end
  end
end
