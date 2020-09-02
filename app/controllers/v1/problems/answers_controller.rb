# frozen_string_literal: true

class V1::Problems::AnswersController < V1Controller
  def index
    CsvJob::Answers.perform_later(current_v1_user.id, params[:problem_id])
    render json: { message: I18n.t('problems.answers.index.csv') }
  end
end
