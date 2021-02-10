# frozen_string_literal: true

require 'faker'
require 'factory_bot'

namespace :db do
  namespace :seed do
    desc 'Creates simple setup for the Team, team_admin and researchers as members'
    task setup_teams: :environment do
      FactoryBot.find_definitions

      ActiveRecord::Base.transaction do
        2.times do
          team = Team.create(name: Faker::Team.name)
          p "Created team #{team.name}"

          create_team_member(
            team,
            %w[team_admin]
          )

          2.times do
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

      intervention   = FactoryBot.create(:intervention, user: u)
      session        = FactoryBot.create(:session, intervention: intervention)
      question_group = FactoryBot.create(:question_group, session: session)
      question_1     = FactoryBot.create(:question_multiple, question_group: question_group)
      question_2     = FactoryBot.create(:question_number, question_group: question_group)
      answer_1       = FactoryBot.create(:answer_multiple, question: question_1)
      FactoryBot.create(:answer_number, question: question_2, user_session: answer_1.user_session)
      FactoryBot.create(:session_invitation, invitable: session)

      p "Created #{u.roles.first} #{u.email}"
    end

    def team_name(team)
      team.name.underscore.tr(' ', '_')
    end
  end
end
