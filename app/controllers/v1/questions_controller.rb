# frozen_string_literal: true

class V1::QuestionsController < V1Controller
  include Resource::Clone
  include Resource::Position

  def index
    render json: serialized_response(questions_scope)
  end

  def show
    render json: serialized_response(question_load)
  end

  def create
    question = questions_scope.new(question_params)
    question.position = questions_scope.last&.position.to_i + 1
    question.save!
    render json: serialized_response(question), status: :created
  end

  def update
    question = question_load
    question.assign_attributes(question_params.except(:type))
    question.execute_narrator
    question.save!
    invalidate_cache(question_load)
    render json: serialized_response(question)
  end

  def destroy
    question_load.destroy
    head :ok
  end

  private

  def questions_scope
    Intervention.friendly.accessible_by(current_ability).find(params[:intervention_id]).questions.includes(%i[image_attachment image_blob]).order(:position)
  end

  def question_load
    questions_scope.find(params[:id])
  end

  def question_params
    params.require(:question).permit(:type, :title, :subtitle, :video_url, narrator: {}, settings: {}, formula: {}, body: {})
  end
end
