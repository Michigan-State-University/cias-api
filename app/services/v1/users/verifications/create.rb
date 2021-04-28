# frozen_string_literal: true

class V1::Users::Verifications::Create
  def self.call(user, verification_code_from_headers)
    new(user, verification_code_from_headers).call
  end

  def initialize(user, verification_code_from_headers)
    @user = user
    @verification_code_from_headers = verification_code_from_headers
  end

  def call
    return if exists_user_with_verification_code? && !code_expired?

    user.update!(verification_code: verification_code, verification_code_created_at: Time.current)
    UserMailer.send_verification_login_code(verification_code: verification_code, email: user.email).deliver_later
  end

  private

  attr_reader :user, :verification_code_from_headers

  def verification_code
    @verification_code ||= SecureRandom.base64(6)
  end

  def code_expired?
    user.verification_code_created_at + 30.days < Time.current
  end

  def exists_user_with_verification_code?
    return false unless verification_code_from_headers

    User.exists?(verification_code: verification_code_from_headers)
  end
end
