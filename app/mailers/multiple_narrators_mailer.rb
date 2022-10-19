# frozen_string_literal: true

class MultipleNarratorsMailer < ApplicationMailer
  def successfully_changed(user, intervention)
    @user = user
    @intervention = intervention
    mail(to: @user.email, subject: I18n.t('multiple_narrators_mailer.subject', intervention_name: @intervention.name))
  end
end
