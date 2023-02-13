# frozen_string_literal: true

class ImportMailer < ApplicationMailer
  def result(user, intervention)
    @user = user
    @intervention = intervention

    mail(to: @user.email, subject: I18n.t('import_mailer.result.subject'))
  end

  def unsuccessful(user)
    @user = user

    mail(to: @user.email, subject: I18n.t('import_mailer.unsuccessful.subject'))
  end
end
