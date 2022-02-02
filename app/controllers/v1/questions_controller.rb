# frozen_string_literal: true

class V1::QuestionsController < V1Controller
  include Resource::Clone

  def index
    authorize! :read, Question

    render json: serialized_response(questions_scope)
  end

  def show
    authorize! :read, Question

    render json: serialized_response(question_load)
  end

  def create
    authorize! :create, Question

    question = V1::Question::Create.call(question_group_load, question_params)

    render json: serialized_response(question), status: :created
  end

  def update
    authorize! :update, Question

    question = V1::Question::Update.call(question_load, question_params)
    invalidate_cache(question)

    render json: serialized_response(question)
  end

  def destroy
    authorize! :delete, Question

    V1::Question::Destroy.call(chosen_questions, question_ids)

    head :no_content
  end

  def move
    authorize! :update, Question

    SqlQuery.new(
      'resource/question_bulk_update',
      values: position_params[:position]
    ).execute
    render json: serialized_response(question_groups_scope, 'QuestionGroup')
  end

  def share
    authorize! :create, Question
    require 'pry'; binding.pry

    V1::Question::ShareService.call(current_v1_user, question_ids, chosen_questions, researcher_ids)

    head :created
  end

  def clone_multiple
    authorize! :create, Question

    cloned_questions = V1::Question::CloneMultiple.call(question_ids, chosen_questions)

    render json: serialized_response(cloned_questions), status: :created
  end

  private

  def question_group_load
    QuestionGroup.includes(:questions).accessible_by(current_ability).find(question_group_id)
  end

  def questions_scope
    question_group_load.questions.order(:position)
  end

  def question_load
    questions_scope.find(question_id)
  end

  def chosen_questions
    Question.accessible_by(current_ability).where(id: question_ids)
  end

  def questions_scope_by_session
    Session.includes(%i[question_groups
                        questions]).accessible_by(current_ability).find(session_id).questions.order(:position)
  end

  def question_groups_scope
    Session.includes(%i[question_groups
                        questions]).accessible_by(current_ability).find(session_id).question_groups.order(:position)
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
