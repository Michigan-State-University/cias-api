# frozen_string_literal: true

class V1::Users::Verifications::Confirm
  def self.call(verification_code)
    new(verification_code).call
  end

  def initialize(verification_code)
    @verification_code = verification_code
  end

  def call
    return if code_expired?

    user.update!(confirmed_verification: true)
    verification_code
  end

  private

  attr_reader :verification_code

  def user
    @user ||= User.find_by!(verification_code: verification_code)
  end

  def code_expired?
    user.verification_code_created_at + 30.minutes < Time.current
  end
end
