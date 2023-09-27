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
    return if verification_code_from_headers && verification_code && !code_expired?

    user.user_verification_codes.create!(code: code)
    UserMailer.send_verification_login_code(verification_code: code, email: user.email).deliver_later # TODO: locale
  end

  private

  attr_reader :user, :verification_code_from_headers

  def code
    @code ||= SecureRandom.base64(6)
  end

  def code_expired?
    expired = verification_code.created_at + 30.days < Time.current
    verification_code.delete if expired
    expired
  end

  def verification_code
    @verification_code ||= user.user_verification_codes&.find_by(code: verification_code_from_headers)
  end
end
