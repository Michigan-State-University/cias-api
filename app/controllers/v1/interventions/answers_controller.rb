# frozen_string_literal: true

class V1::Interventions::AnswersController < V1Controller
  def index
    CsvJob::Answers.perform_later(current_v1_user.id, params[:intervention_id])
    render json: { message: I18n.t('interventions.answers.index.csv') }
  end
end
