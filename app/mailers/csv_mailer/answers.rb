# frozen_string_literal: true

class CsvMailer::Answers < CsvMailer
  def csv_answers(user, intervention, blob_path)
    @user = user
    @intervention = intervention
    @blob_path = blob_path
    mail(to: @user.email, subject: I18n.t('csv_mailer.answers.subject', intervention_name: @intervention.name))
  end
end
