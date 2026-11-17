# frozen_string_literal: true

class V1::Users::CreateGuest
  def self.call(phone_number = false)
    new.call(phone_number)
  end

  def call(phone_number)
    new_user = User.new.tap do |user|
      user.roles = %w[guest]
      user.skip_confirmation!
      user.email = "#{Time.current.to_i}_#{SecureRandom.hex(10)}@guest.true"
      user.save(validate: false)
    end

    if phone_number
      parts = Phone::NumberAnalysis.lookup_parts(phone_number)
      iso = Phonelib.parse(phone_number).country

      Phone.new(prefix: parts[:prefix], number: parts[:number], iso: iso, user: new_user).save!
    end

    new_user
  end
end
