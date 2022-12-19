# frozen_string_literal: true

class MultipleNarratorsMailer < ApplicationMailer
  def successfully_changed(user_email, object)
    @user_email = user_email
    @object = object
    mail(to: user_email, subject: I18n.t('multiple_narrators_mailer.subject', intervention_name: @object.name))
  end
end
