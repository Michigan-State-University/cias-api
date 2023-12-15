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
    @link_to_session = link_to_session(session, health_clinic, email)

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

  private

  def link_to_session(session, health_clinic, email)
    user = User.find_by(email: email)
    return "#{ENV['WEB_URL']}/usr/#{user.predefined_user_parameter.slug}" if user&.roles&.include?('predefined_participant')

    if session.intervention.shared_to_anyone?
      (if health_clinic.nil?
         I18n.t('session_mailer.inform_to_an_email.invitation_link_for_anyone',
                domain: ENV['WEB_URL'], session_id: session.id,
                intervention_id: session.intervention_id)
       else
         I18n.t('session_mailer.inform_to_an_email.invitation_link_for_anyone_from_clinic',
                domain: ENV['WEB_URL'], session_id: session.id,
                intervention_id: session.intervention_id,
                health_clinic_id: health_clinic.id)
       end)
    else
      (if health_clinic.nil?
         I18n.t('session_mailer.inform_to_an_email.invitation_link',
                domain: ENV['WEB_URL'],
                intervention_id: session.intervention_id, session_id: session.id)
       else
         I18n.t('session_mailer.inform_to_an_email.invitation_link_from_clinic',
                domain: ENV['WEB_URL'],
                intervention_id: session.intervention_id, session_id: session.id,
                health_clinic_id: health_clinic.id)
       end)
    end
  end
end
