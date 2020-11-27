# frozen_string_literal: true

class CsvMailer::Answers < CsvMailer
  def csv_answers(user, intervention)
    @user = user
    @intervention = intervention
    mail(to: @user.email, subject: I18n.t('csv_mailer.answers.subject', intervention_name: @intervention.name))
  end
end
