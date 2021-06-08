# frozen_string_literal: true

class V1::Users::Verifications::Confirm
  def self.call(verification_code, email)
    new(verification_code, email).call
  end

  def initialize(verification_code, email)
    @verification_code = verification_code
    @email = email
  end

  def call
    return if code_expired?

    user_verification_code.update!(confirmed: true)
    user_verification_code.code
  end

  private

  attr_reader :verification_code, :email

  def user
    User.find_by!(email: email)
  end

  def code_expired?
    user_verification_code.created_at + 30.minutes < Time.current
  end

  def user_verification_code
    @user_verification_code ||= user.user_verification_codes.find_by!(code: verification_code)
  end
end
