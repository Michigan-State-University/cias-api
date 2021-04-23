# frozen_string_literal: true

class V1::Users::Verifications::Create
  def self.call(user, verification_code_from_cookies)
    new(user, verification_code_from_cookies).call
  end

  def initialize(user, verification_code_from_cookies)
    @user = user
    @verification_code_from_cookies = verification_code_from_cookies
  end

  def call
    return if user.verification_code.present? && !code_expired? && verification_code_from_cookies.present?

    user.update!(verification_code: verification_code, verification_code_created_at: Time.current)
    UserMailer.send_verification_login_code(verification_code: verification_code, email: user.email).deliver_later
  end

  private

  attr_reader :user, :verification_code_from_cookies

  def verification_code
    @verification_code ||= SecureRandom.base64(6)
  end

  def code_expired?
    user.verification_code_created_at + 30.days < Time.current
  end
end
