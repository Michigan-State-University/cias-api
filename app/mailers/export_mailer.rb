# frozen_string_literal: true

class ExportMailer < ApplicationMailer
  def result(user, intervention_name, file_path)
    @user = user
    @intervention_name = intervention_name

    file_name = intervention_name.gsub(/[^0-9a-zA-Z\-]/, ' ').gsub(/\s/, '-')
    attachments["#{file_name}-backup.json"] = File.read(file_path)
    mail(to: @user.email, subject: I18n.t('backup_mailer.result.subject'))
  end
end
