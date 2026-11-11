# frozen_string_literal: true

require 'faker'

class SummonUsers
  class << self
    def onboarding
      summon_many
    end

    private

    def summon_many
      roles.each do |role|
        u = User.new(
          first_name: role,
          last_name: Faker::GreekPhilosophers.name,
          email: "#{role}@#{ENV.fetch('DOMAIN_NAME', nil)}",
          password: 'Password123!',
          roles: [role],
          terms: true
        )
        u.confirm
        u.save
        u.user_verification_codes.create(code: SecureRandom.base64(6), confirmed: true)
      end
    end

    def roles
      User::APP_ROLES - %w[team_admin preview_session organization_admin e_intervention_admin third_party]
    end
  end
end

SummonUsers.onboarding
