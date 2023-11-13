# frozen_string_literal: true

class ExportMailer < ApplicationMailer
  def result(user, intervention)
    @user = user
    @intervention = intervention

    mail(to: @user.email, subject: I18n.t('backup_mailer.result.subject'))
  end
end
