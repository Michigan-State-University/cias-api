# frozen_string_literal: true

class SessionMailer < ApplicationMailer
  def grant_access_to_a_user(session, email)
    @session = session
    @email = email
    mail(to: @email, subject: I18n.t('session_mailer.grant_access_to_a_user'))
  end

  def inform_to_an_email(session, email)
    @session = session
    @email = email
    mail(to: @email, subject: I18n.t('session_mailer.inform_to_an_email'))
  end
end
