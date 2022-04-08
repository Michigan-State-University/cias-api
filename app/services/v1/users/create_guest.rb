# frozen_string_literal: true

class V1::Users::CreateGuest
  def self.call
    new.call
  end

  def call
    User.new.tap do |user|
      user.roles = %w[guest]
      user.skip_confirmation!
      user.email = "#{Time.current.to_i}_#{SecureRandom.hex(10)}@guest.true"
      user.save(validate: false)
    end
  end
end
