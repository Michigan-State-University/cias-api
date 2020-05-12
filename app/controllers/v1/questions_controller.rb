# frozen_string_literal: true

class V1::QuestionsController < ApplicationController
  def index
    render json: QuestionSerializer.new(questions_scope).serialized_json
  end

  def create
    question = questions_scope.create!(question_params)
    render json: question, status: :created
  end

  private

  def questions_scope
    Question.includes(:intervention).accessible_by(current_ability).where(intervention_id: params[:intervention_id])
  end

  def question_params
    params.require(:question).permit(:type, :previous_id, :title, :subtitle, body: {})
  end
end
