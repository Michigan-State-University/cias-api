# frozen_string_literal: true

class V1::QuestionGroup::ShareService
  def initialize(user, session_id)
    @user = user
    @session = Session.accessible_by(user.ability).find(session_id)
    @intervention = Intervention.accessible_by(user.ability).find(session.intervention_id)
    @all_user_questions = Question.accessible_by(user.ability)
    @question_groups = QuestionGroup.includes(:session, :questions).accessible_by(user.ability).where(session_id: session_id).order(:position)
  end

  attr_reader :user, :intervention, :session, :all_user_questions
  attr_accessor :question_groups

  def question_group_load(qg_id)
    question_groups.find(qg_id)
  end

  def share(shared_question_group_id, question_group_ids, question_ids)
    raise CanCan::AccessDenied if question_group_intervention_published?

    shared_question_group = question_group_load(shared_question_group_id)

    Question.transaction do
      shared_questions = shared_question_group.questions

      question_ids.each do |question_id|
        question = all_user_questions.find(question_id)
        if can_copy_this_question(shared_questions, question)
          share_question(shared_questions, question)
        else
          return nil
        end
      end

      question_group_ids.each do |question_group_id|
        questions = all_user_questions.where(question_group_id: question_group_id)
        next if questions.empty?

        share_question_group_questions(shared_questions, questions, question_ids)
      end
    end

    shared_question_group.reload
  end

  private

  def question_group_intervention_published?
    intervention.published?
  end

  def share_question_group_questions(shared_questions, questions, question_ids)
    questions.each do |question|
      next if question_ids.include?(question.id)

      share_question(shared_questions, question)
    end
  end

  def share_question(shared_questions, question)
    cloned = question.clone
    cloned.clear_narrator_blocks
    cloned.position = shared_questions.last&.position.to_i + 1
    shared_questions << cloned
  end

  def can_copy_this_question(shared_questions, question)
    if question.type.eql? 'Question::Name' || 'Question::ParticipantReport' || 'Question::ThirdParty'
      shared_questions.each do |shared_question|
        shared_question
        return false if shared_question.type.eql? question.type
      end
    end

    true
  end
end
