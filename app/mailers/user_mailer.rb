# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def send_verification_login_code(verification_code:, email:)
    @verification_code = verification_code
    @email = email
    subject = I18n.t('user_mailer.send_verification_login_code.subject')
    mail(to: email, subject: subject)
  end

  def welcome_email(role, email)
    @email = email
    @role = role
    mail(to: email, subject: I18n.t('user_mailer.welcome_email.subject'))
  end
end
