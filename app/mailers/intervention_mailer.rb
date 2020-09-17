# frozen_string_literal: true

class InterventionMailer < ApplicationMailer
  def grant_access_to_a_user(intervention, email)
    @intervention = intervention
    @email = email
    mail(to: @email, subject: I18n.t('intervention_mailer.grant_access_to_a_user'))
  end

  def inform_to_an_email(intervention, email)
    @intervention = intervention
    @email = email
    mail(to: @email, subject: I18n.t('intervention_mailer.inform_to_an_email'))
  end
end
