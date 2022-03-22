# frozen_string_literal: true

class V1::QuestionGroupsController < V1Controller
  include Resource::Position

  def index
    raise ActiveRecord::RecordNotFound, 'Session not found' if question_groups_scope.empty?

    render json: question_group_response(question_groups_scope)
  end

  def show
    render json: question_group_response(question_group_load)
  end

  def create
    authorize! :create, QuestionGroup

    question_group = V1::QuestionGroup::CreateService.call(question_group_params, questions_scope, new_questions_params, session_load)
    SqlQuery.new('question_group/question_group_pure_empty').execute

    render json: question_group_response(question_group.reload), action: :show,
           status: :created
  end

  def update
    authorize! :update, QuestionGroup

    question_group = V1::QuestionGroup::UpdateService.call(question_group_load, question_group_params)

    render json: question_group_response(question_group), action: :show
  end

  def destroy
    authorize! :destroy, QuestionGroup

    question_group = question_group_load
    question_group.destroy! unless question_group.finish?

    head :no_content
  end

  def questions_change
    authorize! :update, QuestionGroup

    question_group = V1::QuestionGroup::QuestionsChangeService.call(question_group_load, questions_scope)

    render json: question_group_response(question_group), action: :show
  end

  def remove_questions
    authorize! :update, QuestionGroup

    questions_scope.destroy_all

    head :no_content
  end

  def clone
    authorize! :create, QuestionGroup

    cloned_question_group = question_group_load.clone(clean_formulas: true)

    render json: question_group_response(cloned_question_group), action: :show, status: :ok
  end

  def share
    authorize! :create, QuestionGroup

    shared_question_group = question_group_share_service.share(question_group_id, question_group_ids, question_ids)

    render json: question_group_response(shared_question_group), action: :show, status: :ok
  end

  private

  def question_group_share_service
    @question_group_share_service ||= V1::QuestionGroup::ShareService.new(current_v1_user, session_load)
  end

  def question_groups_scope
    @question_groups_scope ||= QuestionGroup.includes(:session, :questions).accessible_by(current_ability).where(session_id: session_id).order(:position)
  end

  def question_group_load
    question_groups_scope.find(question_group_id)
  end

  def questions_scope
    Question.accessible_by(current_ability).where(id: question_ids)
  end

  def session_load
    Session.accessible_by(current_ability).find(session_id)
  end

  def new_questions_params
    params[:question_group][:questions]
  end

  def question_ids
    params[:question_group][:question_ids]
  end

  def question_group_params
    params.require(:question_group).permit(:title, :session_id, :type)
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
