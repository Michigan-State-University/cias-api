# frozen_string_literal: true

class V1::QuestionGroupsController < V1Controller
  include Resource::Position

  def index
    question_groups = question_groups_scope.includes(:questions).order(:position).all

    render_json question_groups: question_groups
  end

  def show
    render_json question_group: question_group_load
  end

  def create
    authorize! :create, QuestionGroup

    question_group = ActiveRecord::Base.transaction do
      question_group = intervention_load.question_groups.create!(question_group_params)
      questions_scope.update_all(question_group_id: question_group.id) # rubocop:disable Rails/SkipsModelValidations

      question_group
    end

    render_json question_group: question_group.reload, action: :show, status: :created
  end

  def update
    authorize! :update, QuestionGroup

    question_group = question_group_load
    question_group.update!(question_group_params)

    render_json question_group: question_group, action: :show
  end

  def destroy
    authorize! :destroy, QuestionGroup

    question_group_load.destroy!

    head :no_content
  end

  def questions_change
    authorize! :update, QuestionGroup

    question_group = question_group_load
    questions_scope.update_all(question_group_id: question_group.id) # rubocop:disable Rails/SkipsModelValidations

    render_json question_group: question_group.reload, action: :show
  end

  def remove_questions
    authorize! :update, QuestionGroup

    questions_scope.destroy_all

    head :no_content
  end

  def clone
    authorize! :create, QuestionGroup

    cloned_question_group = question_group_load.clone(params)

    render_json question_group: cloned_question_group, action: :show, status: :ok
  end

  def share # TODO: Implement business logic
    authorize! :create, QuestionGroup
  end

  private

  def question_groups_scope
    QuestionGroup.includes(:intervention, :questions).accessible_by(current_ability).where(intervention_id: params[:intervention_id])
  end

  def question_group_load
    question_groups_scope.find(params[:id])
  end

  def intervention_load
    question_groups_scope.first.intervention
  end

  def questions_scope
    Question.accessible_by(current_ability).where(id: params[:question_group][:questions])
  end

  def question_group_params
    params.require(:question_group).permit(:title, :position, :intervention_id)
  end

  def question_groups_positions_params
    params.require(:question_groups).permit(positions: %i[id position])
  end
end
