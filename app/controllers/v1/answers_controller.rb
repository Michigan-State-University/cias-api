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
    answer = V1::AnswerService.new(current_v1_user).create(params[:question_id], answer_params)
    render json: serialized_response(answer), status: :created
  end

  private

  def answers_scope
    Answer.includes(:question, :user_session).accessible_by(current_ability).where(question_id: params[:question_id])
  end

  def answer_load
    answers_scope.find(params[:id])
  end

  def answer_params
    params.require(:answer).permit(:type, body: {})
  end
end
