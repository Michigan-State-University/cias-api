# frozen_string_literal: true

namespace :users do
  desc 'Split roles to contain unique behavior and adjust exist roles to this structure'
  task add_additional_roles_to_existed_users: :environment do
    user_count = User.count
    User.find_each.with_index do |user, index|
      p "Checking and updating user: Progress #{index + 1}/#{user_count}"

      user.update!(roles: %w[researcher team_admin]) if user.team_admin?

      user.update!(roles: (['researcher'] << user.roles).flatten.uniq) if user.e_intervention_admin?
    end
    p 'Task done'
  end
end
