# frozen_string_literal: true

class V1::Interventions::AnswersController < V1Controller
  def index
    requested_at = Time.current.utc
    day_format = ActiveSupport::Inflector.ordinalize(requested_at.day)
    formatted_requested_at = requested_at.strftime("%B #{day_format}, %Y %H:%M %Z")
    CsvJob::Answers.perform_later(current_v1_user.id, params[:intervention_id], formatted_requested_at)
    render json: { message: I18n.t('interventions.answers.index.csv') }
  end
end
