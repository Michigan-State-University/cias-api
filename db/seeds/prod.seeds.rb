# frozen_string_literal: true

require 'faker'

class CreateProdUsers
  class << self
    def onboarding
      create_users
    end

    private

    def create_users
      if User.find_by_email('michal.sniec@htdevelopers.com')
        p 'Users exists'
        return
      end
      %w[michal.sniec@htdevelopers.com natalia.kolinska@htdevelopers.com arkadiusz.tubicz@htdevelopers.com onders12@msu.edu].each_with_index do |email, _index|
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
