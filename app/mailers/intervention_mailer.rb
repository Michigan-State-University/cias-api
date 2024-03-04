# frozen_string_literal: true

class InterventionMailer < ApplicationMailer
  def inform_to_an_email(intervention, email, health_clinic = nil)
    @intervention = intervention
    @email = email
    @link = V1::SessionOrIntervention::Link.call(intervention, health_clinic, email)

    mail(to: @email, subject: I18n.t('intervention_mailer.inform_to_an_email.subject'))
  end

  def invite_to_intervention_and_registration(intervention, email, health_clinic = nil)
    @intervention = intervention
    @email = email
    @health_clinic = health_clinic
    @user = User.find_by(email: email)
    @user.send(:generate_invitation_token!) # same as in session mailer
    @invitation_token = @user.raw_invitation_token

    mail(to: @email, subject: I18n.t('intervention_mailer.invite_to_intervention_and_registration.subject'))
  end
end
