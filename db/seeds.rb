# frozen_string_literal: true

require 'faker'

class SummonUsers
  class << self
    def onboarding
      summon_many
      create_example_hfhs_data
    end

    private

    def summon_many
      roles.each do |role|
        u = User.new(
          first_name: role,
          last_name: Faker::GreekPhilosophers.name,
          email: "#{role}@#{ENV['DOMAIN_NAME']}",
          password: 'Password1!',
          roles: [role],
          terms: true
        )
        u.confirm
        u.save
        u.user_verification_codes.create(code: SecureRandom.base64(6), confirmed: true)
      end
    end

    def create_example_hfhs_data
      HfhsPatientDetail.create(
        first_name: 'Cias',
        last_name: 'Team',
        sex: 'U',
        dob: Date.new(1978, 8, 9),
        zip_code: '49201-1653',
        patient_id: '89008700',
        visit_id: 'H93905_1010010049_10727228307'
      )

      %w[89008709 1482928].each do |mrn|
        HfhsPatientDetail.create(
          first_name: 'Fred',
          last_name: 'Flintstone',
          sex: 'M',
          dob: Date.new(2002, 2, 2),
          zip_code: '49201-1653',
          patient_id: mrn
        )
      end
    end

    def roles
      User::APP_ROLES - %w[team_admin preview_session organization_admin e_intervention_admin third_party]
    end
  end
end

SummonUsers.onboarding
