# frozen_string_literal: true

class CsvMailer::Answers < CsvMailer
  def csv_answers(user, problem, csv_file)
    @user = user
    @problem = problem
    timestamp = Time.current.in_time_zone(@user.time_zone).strftime(ENV.fetch('FILE_TIMESTAMP_NOTATION', '%m-%d-%Y_%H%M'))
    filename = "#{timestamp}_#{@problem.name.parameterize.underscore[..12]}.csv"
    attachments[filename] = {
      mime_type: 'text/csv',
      encoding: 'base64',
      content: csv_file
    }
    mail(to: @user.email, subject: I18n.t('csv_mailer.answers.subject', problem_name: @problem.name))
  end
end
