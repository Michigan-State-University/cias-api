# frozen_string_literal: true

class V1::QuestionsController < V1Controller
  def index
    render json: serialized_response(questions_scope)
  end

  def show
    render json: serialized_response(question_load)
  end

  def create
    question = questions_scope.create!(question_params)
    render json: serialized_response(question), status: :created
  end

  def update
    question_load.update!(question_params.except(:type))
    invalidate_cache(question_load)
    render json: serialized_response(question_load)
  end

  def destroy
    question_load.destroy
    head :ok
  end

  private

  def questions_scope
    Question.includes(image_attachment: :blob).accessible_by(current_ability).where(intervention_id: params[:intervention_id])
  end

  def question_load
    questions_scope.find(params[:id])
  end

  def question_params
    params.require(:question).permit(:type, :order, :title, :subtitle, :video_url, narrator: {}, settings: {}, formula: {}, body: {})
  end
end
