# frozen_string_literal: true

class V1::QuestionsController < V1Controller
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

  def clone
    question = question_load.dup
    question.image.attach(question_load.image.blob) if question_load.image.attachment
    question.save!
    render json: serialized_response(question), status: :created
  end

  def position
    SqlQuery.new(
      'question/position_bulk_update',
      values: question_position_params[:position]
    ).execute
    invalidate_cache(questions_scope)
    render json: serialized_response(questions_scope)
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
    Intervention.friendly.accessible_by(current_ability).find(params[:intervention_id]).questions.order(:position)
  end

  def question_load
    questions_scope.find(params[:id])
  end

  def question_params
    params.require(:question).permit(:type, :title, :subtitle, :video_url, narrator: {}, settings: {}, formula: {}, body: {})
  end

  def question_position_params
    params.require(:question).permit(position: %i[id position])
  end
end
