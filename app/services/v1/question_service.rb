# frozen_string_literal: true

class V1::QuestionService
  def initialize(user)
    @user = user
  end

  attr_reader :user

  def question_groups_scope(session_id)
    Session.includes(%i[question_groups questions]).accessible_by(user.ability).find(session_id).question_groups.order(:position)
  end

  def questions_scope_by_session(session_id)
    Session.includes(%i[question_groups questions]).accessible_by(user.ability).find(session_id).questions.order(:position)
  end

  def question_group_load(question_group_id)
    QuestionGroup.accessible_by(user.ability).find(question_group_id)
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

  def create(question_group_id, question_params)
    question = questions_scope(question_group_id).new(question_params)
    question.position = questions_scope(question_group_id).last&.position.to_i + 1
    question.save!
    question
  end

  def update(question_group_id, question_id, question_params)
    question = question_load(question_group_id, question_id)
    question.assign_attributes(question_params.except(:type))
    question.execute_narrator
    question.save!
    question
  end

  def destroy(session_id, question_ids)
    questions = questions_scope_by_session(session_id)

    Question.transaction do
      question_ids.each do |question_id|
        question = questions.find(question_id)
        question.destroy!
        qg = question.question_group
        qg.destroy! if questions_scope(qg.id).empty?
      end
    end
  end
end
