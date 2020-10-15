# frozen_string_literal: true

class V1::QuestionsController < V1Controller
  include Resource::Clone

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
    question_load.destroy!
    head :no_content
  end

  def move
    authorize! :update, Question

    SqlQuery.new(
      'resource/question_bulk_update',
      values: position_params[:position]
    ).execute
    invalidate_cache(question_groups_scope)
    render_json question_groups: question_groups_scope, path: 'v1/question_groups', action: :index
  end

  private

  def question_groups_scope
    Intervention.includes(%i[question_groups questions]).accessible_by(current_ability).find(params[:intervention_id]).question_groups
  end

  def questions_scope
    QuestionGroup.accessible_by(current_ability).find(params[:question_group_id]).questions.includes(%i[image_attachment image_blob]).order(:position)
  end

  def question_load
    questions_scope.find(params[:id])
  end

  def question_params
    params.require(:question).permit(:type, :title, :subtitle, :video_url, narrator: {}, settings: {}, formula: {}, body: {})
  end

  def position_params
    params.require(:question).permit(position: %i[id position question_group_id])
  end
end
