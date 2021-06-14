# frozen_string_literal: true

require 'faker'

class SummonUsers
  class << self
    def onboarding
      summon_many
    end

    private

    def summon_many
      roles.each_with_index do |role, _index|
        u = User.new(
          first_name: role,
          last_name: Faker::GreekPhilosophers.name,
          email: "#{role}@#{ENV['DOMAIN_NAME']}",
          password: 'Password1!',
          roles: [role]
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

class GoogleTtsVoices
  class << self
    def onboarding
      Rake::Task['google_tts_languages:fetch'].invoke
    end
  end
end

class GoogleLanguages
  class << self
    def onboarding
      Rake::Task['google_languages:fetch'].invoke
    end
  end
end

SummonUsers.onboarding
GoogleTtsVoices.onboarding
GoogleLanguages.onboarding
