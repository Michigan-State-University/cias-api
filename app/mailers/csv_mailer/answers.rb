# frozen_string_literal: true

class CsvMailer::Answers < CsvMailer
  def csv_answers(user, intervention, requested_at)
    @user = user
    @intervention = intervention
    @requested_at = requested_at
    mail(to: @user.email, subject: I18n.t('csv_mailer.answers.subject', intervention_name: @intervention.name))
  end

  def csv_answers_preview(user, intervention, csv_content, requested_at)
    @user = user
    @intervention = intervention
    @requested_at = requested_at
    attachments['preview.csv'] = { mime_type: 'text/csv', content: csv_content }
    mail(to: @user.email, subject: I18n.t('csv_mailer.answers.preview.subject', intervention_name: @intervention.name))
  end
end
