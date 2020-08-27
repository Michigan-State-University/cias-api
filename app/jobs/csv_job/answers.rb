# frozen_string_literal: true

class CsvJob::Answers < CsvJob
  def perform(user_id, problem_id)
    user = User.find(user_id)
    problem = Problem.find(problem_id)
    MetaOperations::FilesKeeper.new(
      stream: problem.export_answers_as(type: module_name), add_to: problem,
      macro: :reports, ext: :csv, type: 'text/csv', user: user
    ).execute
    CsvMailer::Answers.csv_answers(user, problem).deliver_now
  end
end
