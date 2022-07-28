# frozen_string_literal: true

class ExportMailer < ApplicationMailer
  def result(user, intervention_name, file_path)
    @user = user
    @intervention_name = intervention_name

    attachments["#{intervention_name}_backup.json"] = File.read(file_path)
    mail(to: @user.email, subject: I18n.t('backup_mailer.result.subject'))
  end
end
