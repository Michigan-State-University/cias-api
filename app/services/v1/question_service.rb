# frozen_string_literal: true

class V1::QuestionService < V1::Question::BaseService
  def question_groups_scope(session_id)
    Session.includes(%i[question_groups questions]).accessible_by(user.ability).find(session_id).question_groups.order(:position)
  end

  def questions_scope_by_session(session_id)
    Session.includes(%i[question_groups questions]).accessible_by(user.ability).find(session_id).questions.order(:position)
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

  def clone_multiple(session_id, question_ids)
    questions = questions_scope_by_session(session_id).where(id: question_ids)
    raise ActiveRecord::RecordNotFound unless proper_questions?(questions, question_ids)

    question_group_id = questions.first&.question_group_id
    question_group = if all_questions_from_one_question_group?(questions, question_group_id)
                       question_group_load(question_group_id)
                     else
                       question_groups = question_groups_scope(session_id)
                       position = question_groups.where(type: 'QuestionGroup::Plain').last&.position.to_i + 1
                       question_groups.create!(title: 'Copied Questions', position: position)
                     end

    clone_questions(questions, question_group)
  end

  private

  def clone_questions(questions, question_group)
    question_group_questions = question_group.questions

    Question.transaction do
      questions.each do |question|
        raise ActiveRecord::RecordNotUnique, (I18n.t 'activerecord.errors.models.question_group.question', question_type: question.type) if question_type_must_be_unique(question)

        cloned = question.clone
        cloned.position = question_group_questions.last&.position.to_i + 1
        question_group_questions << cloned
      end
    end
    question_group.destroy! if question_group.questions.size.eql?(0)
    question_group_questions.last(questions.size)
  end

  def all_questions_from_one_question_group?(questions, question_group_id)
    questions.all? { |question| question.question_group_id.eql?(question_group_id) }
  end

  def question_type_must_be_unique(question)
    [::Question::Name, ::Question::ParticipantReport, ::Question::ThirdParty, ::Question::Phone].member? question.class
  end
end
