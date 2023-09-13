# frozen_string_literal: true

class SessionMailer < ApplicationMailer
  def grant_access_to_a_user(session, email)
    @session = session
    @email = email
    mail(to: @email, subject: I18n.t('session_mailer.grant_access_to_a_user.subject'))
  end

  def inform_to_an_email(session, email, health_clinic = nil, scheduled_at = nil)
    @session = session
    @email = email
    @health_clinic = health_clinic
    @scheduled_at = scheduled_at

    mail(to: @email, subject: I18n.t('session_mailer.inform_to_an_email.subject'))
  end

  def invite_to_session_and_registration(session, email, health_clinic = nil)
    @email = email
    @session = session
    @health_clinic = health_clinic
    @user = User.find_by(email: email)
    @user.send(:generate_invitation_token!) # needed because for some reason the raw token is empty
    @invitation_token = @user.raw_invitation_token

    mail(to: @email, subject: I18n.t('session_mailer.invite_to_session_and_registration.subject'))
  end
end
