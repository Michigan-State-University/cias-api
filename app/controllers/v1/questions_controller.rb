# frozen_string_literal: true

class V1::QuestionsController < V1Controller
  include Resource::Clone

  def index
    render json: serialized_response(questions_scope)
  end

  def show
    render json: serialized_response(question_service.question_load(question_group_id, question_id))
  end

  def create
    question = question_service.create(question_group_id, question_params)

    render json: serialized_response(question), status: :created
  end

  def update
    question = question_service.update(question_group_id, question_id, question_params)
    invalidate_cache(question_service.question_load(question_group_id, question_id))

    render json: serialized_response(question)
  end

  def destroy
    question_service.destroy(session_id, question_ids)

    head :no_content
  end

  def move
    authorize! :update, Question

    SqlQuery.new(
      'resource/question_bulk_update',
      values: position_params[:position]
    ).execute
    question_groups = question_service.question_groups_scope(session_id)
    render json: serialized_response(question_groups, 'QuestionGroup')
  end

  def share
    authorize! :create, Question
    share_service.share(question_ids, researcher_ids)

    head :created
  end

  def clone_multiple
    authorize! :create, Question
    cloned_questions = question_service.clone_multiple(session_id, question_ids)

    render json: serialized_response(cloned_questions), status: :created
  end

  private

  def question_service
    @question_service ||= V1::QuestionService.new(current_v1_user)
  end

  def share_service
    @share_service ||= V1::Question::ShareService.new(current_v1_user)
  end

  def questions_scope
    question_service.questions_scope(question_group_id)
  end

  def question_group_id
    params[:question_group_id]
  end

  def question_id
    params[:id]
  end

  def question_ids
    params[:ids]
  end

  def session_id
    params[:session_id]
  end

  def researcher_ids
    params[:researcher_ids]
  end

  def question_params
    params.require(:question).permit(:type, :question_group_id, :title, :subtitle, :video_url, narrator: {},
                                                                                               settings: {}, formula: {}, body: {})
  end

  def position_params
    params.require(:question).permit(position: %i[id position question_group_id])
  end
end
