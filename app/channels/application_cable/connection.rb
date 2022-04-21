# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    def disconnect
      # Any cleanup work needed when the cable connection is cut.
    end

    private

    def find_verified_user
      uid, token, client_id = params
      user = User.find_by(uid: uid)

      if user&.valid_token?(token, client_id)
        user
      else
        reject_unauthorized_connection
      end
    end

    def params
      [request.params['uid'], request.params['access_token'], request.params['client']]
    end
  end
end
