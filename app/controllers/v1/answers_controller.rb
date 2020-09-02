# frozen_string_literal: true

class V1::AnswersController < V1Controller
  authorize_resource only: :create

  def index
    render json: serialized_response(answers_scope)
  end

  def show
    render json: serialized_response(answer_load)
  end

  def create
    answer = answers_scope.create!(user_id: current_v1_user.id, **answer_params)
    intervention_or_question = answer.perform_response
    render json: serialized_response(
      intervention_or_question,
      intervention_or_question&.de_constantize_modulize_name || NilClass
    )
  end

  private

  def answers_scope
    Answer.includes(:question, :user).accessible_by(current_ability).where(question_id: params[:question_id])
  end

  def answer_load
    answers_scope.find(params[:id])
  end

  def answer_params
    params.require(:answer).permit(:type, body: {})
  end
end
