# frozen_string_literal: true

class V1::Question::BaseService
  def initialize(user)
    @user = user
  end

  attr_reader :user

  def question_group_load(question_group_id)
    QuestionGroup.includes(:questions).accessible_by(user.ability).find(question_group_id)
  end

  def questions_scope(question_group_id)
    question_group_load(question_group_id).questions.order(:position)
  end

  def question_load(question_group_id, id)
    questions_scope(question_group_id).find(id)
  end

  def chosen_questions(question_group_id, ids)
    questions_scope(question_group_id).where(id: ids)
  end
end
