# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def send_verification_login_code(verification_code:, email:)
    @verification_code = verification_code
    @email = email
    subject = I18n.t('user_mailer.send_verification_login_code.subject')
    mail(to: email, subject: subject)
  end
end
