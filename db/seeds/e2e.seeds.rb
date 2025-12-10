# frozen_string_literal: true

class CreateE2EUsers
  E2E_VERIFICATION_CODE = ENV.fetch('E2E_VERIFICATION_CODE', 'e2e_verification_code')
  E2E_PASSWORD = ENV.fetch('E2E_PASSWORD', 'e2e_password')

  class << self
    def call
      create_e2e_users
    end

    private

    def create_e2e_users
      e2e_roles.each do |role|
        email = "e2e_#{role}@example.com"

        next if User.find_by(email: email)

        user = User.new(
          first_name: 'E2E',
          last_name: role.titleize,
          email: email,
          password: E2E_PASSWORD,
          roles: [role],
          terms: true
        )
        user.confirm
        user.save!
        user.user_verification_codes.create!(code: E2E_VERIFICATION_CODE, confirmed: true)

        puts "Created e2e user: #{email}" # rubocop:disable Rails/Output
      end
    end

    def e2e_roles
      %w[admin researcher participant]
    end
  end
end

CreateE2EUsers.call
