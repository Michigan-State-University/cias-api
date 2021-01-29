# frozen_string_literal: true

class CsvMailer::Answers < CsvMailer
  def csv_answers(user, intervention, requested_at)
    @user = user
    @intervention = intervention
    @requested_at = requested_at
    mail(to: @user.email, subject: I18n.t('csv_mailer.answers.subject', intervention_name: @intervention.name))
  end
end
