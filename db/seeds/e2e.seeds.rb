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
      user_count = ENV.fetch('E2E_WORKER_COUNT', 5).to_i

      e2e_roles.each do |role|
        user_count.times do |i|
          email = "e2e_#{role}_#{i}@example.com"
          User.find_or_create_by!(email: email) do |user|
            user.first_name = 'E2E'
            user.last_name = "#{role.titleize}#{i}"
            user.email = email
            user.password = E2E_PASSWORD
            user.roles = [role]
            user.terms = true
            user.confirm
            user.save!
            user.user_verification_codes.create!(code: E2E_VERIFICATION_CODE, confirmed: true)
            puts "Created e2e user: #{email}" # rubocop:disable Rails/Output
          end
        end
      end
    end

    def e2e_roles
      %w[admin researcher participant]
    end
  end
end

CreateE2EUsers.call
