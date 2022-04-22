# frozen_string_literal: true

class TranslationMailer < ApplicationMailer
  def confirmation(user, intervention, translated_intervention)
    @user = user
    @intervention = intervention
    @translated_intervention = translated_intervention
    mail(to: @user.email, subject: I18n.t('translation_mailer.subject', intervention_name: @translated_intervention.name))
  end

  def error(user)
    @user = user
    mail(to: @user.email, subject: I18n.t('translation_mailer.error.subject'))
  end
end
