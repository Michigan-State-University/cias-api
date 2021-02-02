# frozen_string_literal: true

require 'faker'

namespace :db do
  namespace :seed do
    desc 'Creates simple setup for the Team, team_admin and researchers as members'
    task setup_teams: :environment do
      ActiveRecord::Base.transaction do
        2.times do
          team = Team.create(name: Faker::Team.name)
          p "Created team #{team.name}"

          create_team_member(
            team,
            %w[team_admin]
          )

          5.times do
            create_team_member(
              team,
              ['researcher']
            )
          end
        end
      end
    end

    def create_team_member(team, roles)
      u = User.new(
        first_name: roles.join(' '),
        last_name: Faker::GreekPhilosophers.name,
        email: "#{roles.last}_#{team.users.count + 1}_#{team_name(team)}_@#{ENV['DOMAIN_NAME']}",
        password: ENV['USER_PASSWORD'],
        roles: roles,
        team_id: team.id
      )
      u.confirm
      u.save

      p "Created #{u.roles.first} #{u.email}"
    end

    def team_name(team)
      team.name.underscore.tr(' ', '_')
    end
  end
end
