# frozen_string_literal: true

class CsvMailer::Answers < CsvMailer
  def csv_answers(user, problem)
    @user = user
    @problem = problem
    mail(to: @user.email, subject: I18n.t('csv_mailer.answers.subject', problem_name: @problem.name))
  end
end
