# frozen_string_literal: true

require 'faker'

class CreateProdUsers
  class << self
    def onboarding
      create_users
    end

    private

    def create_users
      ENV['SEED_PROD_ACCOUTS_EMAILS'].split.each_with_index do |email, _index|
        p "Creating user with #{email}" # rubocop:disable Rails/Output

        if User.find_by(email: email)
          p 'Users exists' # rubocop:disable Rails/Output
          next
        end

        u = User.new(
          first_name: 'Admin',
          last_name: 'Account',
          email: email,
          password: 'Password1!',
          roles: ['admin']
        )
        u.confirm
        u.save
        u.user_verification_codes.create(code: SecureRandom.base64(6), confirmed: true)
      end
    end
  end
end

CreateProdUsers.onboarding
