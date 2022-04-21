# frozen_string_literal: true

class InterventionMailer < ApplicationMailer
  def inform_to_an_email(intervention, email, health_clinic = nil)
    @intervention = intervention
    @email = email
    @health_clinic = health_clinic

    mail(to: @email, subject: I18n.t('intervention_mailer.inform_to_an_email.subject'))
  end
end
