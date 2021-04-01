# frozen_string_literal: true

class V1::QuestionGroupsController < V1Controller
  include Resource::Position

  def index
    question_groups = question_groups_scope
    raise ActiveRecord::RecordNotFound, 'Session not found' if question_groups.empty?

    render json: question_group_response(question_groups)
  end

  def show
    render json: question_group_response(question_group_service.question_group_load(question_group_id))
  end

  def create
    authorize! :create, QuestionGroup
    qg_id = question_group_service.create(question_group_params, question_ids, new_questions_params)
    SqlQuery.new('question_group/question_group_pure_empty').execute

    render json: question_group_response(question_group_service.question_group_load(qg_id).reload), action: :show, status: :created
  end

  def update
    authorize! :update, QuestionGroup
    question_group = question_group_service.update(question_group_id, question_group_params)

    render json: question_group_response(question_group), action: :show
  end

  def destroy
    authorize! :destroy, QuestionGroup
    question_group_service.destroy(question_group_id)

    head :no_content
  end

  def questions_change
    authorize! :update, QuestionGroup
    question_group = question_group_service.questions_change(question_group_id, question_ids)

    render json: question_group_response(question_group.reload), action: :show
  end

  def remove_questions
    authorize! :update, QuestionGroup
    question_group_service.questions_scope(question_ids).destroy_all

    head :no_content
  end

  def clone
    authorize! :create, QuestionGroup
    cloned_question_group = question_group_service.question_group_load(question_group_id).clone(params: params.permit!, clean_formulas: true)

    render json: question_group_response(cloned_question_group), action: :show, status: :ok
  end

  def share
    authorize! :create, QuestionGroup
    response = question_group_share_service.share(question_group_id, question_group_ids, question_ids)
    if response[:warning].presence
      render json: { warning: response[:warning] }, status: :conflict
    else
      render json: question_group_response(response[:shared_question_group]), action: :show, status: :ok
    end
  end

  private

  def question_group_service
    @question_group_service ||= V1::QuestionGroupService.new(current_v1_user, session_id)
  end

  def question_group_share_service
    @question_group_share_service ||= V1::QuestionGroup::ShareService.new(current_v1_user, session_id)
  end

  def question_groups_scope
    question_group_service.question_groups
  end

  def new_questions_params
    params[:question_group][:questions]
  end

  def question_ids
    params[:question_group][:question_ids]
  end

  def question_group_params
    params.require(:question_group).permit(:title, :session_id)
  end

  def question_group_id
    params[:id]
  end

  def question_group_ids
    params[:question_group][:question_group_ids]
  end

  def session_id
    params[:session_id]
  end

  def question_groups_positions_params
    params.require(:question_groups).permit(positions: %i[id position])
  end

  def question_group_response(question_groups)
    V1::QuestionGroupSerializer.new(
      question_groups,
      { include: %i[questions] }
    )
  end
end
