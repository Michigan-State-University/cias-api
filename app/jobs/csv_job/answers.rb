# frozen_string_literal: true

class CsvJob::Answers < CsvJob
  def perform(user_id, problem_id)
    user = User.find(user_id)
    problem = Problem.find(problem_id)
    csv_file = problem.export_answers_as(type: module_name)
    CsvMailer::Answers.csv_answers(user, problem, csv_file).deliver_now
  end
end
