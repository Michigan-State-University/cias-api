# frozen_string_literal: true

require 'faker'

# rubocop:disable Style/ClassVars
class SummonUsers
  class << self
    def onboarding
      passwords_harvester
      summon_many
    end

    private

    def passwords_harvester
      @@passwords_harvester ||= ENV.fetch('USER_CREDENTIALS') { raise ArgumentError, 'There are no provided credentials for users' }.split(',')
    end

    def summon_many
      roles.each_with_index do |role, index|
        u = User.new(
          first_name: role,
          last_name: Faker::GreekPhilosophers.name,
          email: "#{role}@#{ENV['DOMAIN_NAME']}",
          password: passwords_harvester[index],
          roles: [role]
        )
        u.confirm
        u.save
      end
    end

    def roles
      User::APP_ROLES - %w[team_admin preview_session]
    end
  end
end
# rubocop:enable Style/ClassVars

SummonUsers.onboarding
