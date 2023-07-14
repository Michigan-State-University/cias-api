# frozen_string_literal: true

class V1::QuestionGroup::ShareService
  def initialize(user, session)
    @user = user
    @session = session
    @intervention = session.intervention
    @all_user_questions = Question.accessible_by(user.ability)
    @question_groups = QuestionGroup.includes(:session,
                                              :questions).accessible_by(user.ability).where(session_id: session.id).order(:position)
  end

  attr_reader :user, :intervention, :session, :all_user_questions
  attr_accessor :question_groups

  def question_group_load(qg_id)
    question_groups.find(qg_id)
  end

  def share(shared_question_group_id, question_group_ids, question_ids, current_user)
    raise CanCan::AccessDenied if question_group_intervention_published?
    raise CanCan::AccessDenied unless intervention.ability_to_update_for?(current_user)

    shared_question_group = question_group_load(shared_question_group_id)

    Question.transaction do
      shared_questions = shared_question_group.questions

      question_ids.each do |question_id|
        question = all_user_questions.find(question_id)
        share_question(shared_questions, question, shared_question_group)
      end

      question_group_ids.each do |question_group_id|
        questions = all_user_questions.where(question_group_id: question_group_id)
        next if questions.empty?

        question_group = QuestionGroup.includes(:questions).find(question_group_id)

        share_question_group_questions(shared_questions, questions, question_ids, question_group)
      end
    end

    shared_question_group.reload
  end

  private

  def question_group_intervention_published?
    intervention.published?
  end

  def share_question_group_questions(shared_questions, questions, question_ids, question_group)
    questions.each do |question|
      next if question_ids.include?(question.id)

      share_question(shared_questions, question, question_group)
    end
  end

  def share_question(shared_questions, question, question_group)
    validate_uniqueness(question, question_group)
    cloned = Clone::Question.new(question, { question_group_id: question_group.id, clean_formulas: true }).execute
    cloned.remove_blocks_with_types(%w[ReflectionFormula Reflection])
    cloned.position = shared_questions.last&.position.to_i + 1
    shared_questions << cloned
  end

  def validate_uniqueness(question, question_group)
    return unless [::Question::Name, ::Question::ParticipantReport, ::Question::ThirdParty,
                   ::Question::Phone].member? question.class

    return unless question_type_exist_in_session(question, question_group)

    raise ActiveRecord::RecordNotUnique, (I18n.t 'activerecord.errors.models.question_group.question', question_type: question.type)
  end

  def question_type_exist_in_session(question, question_group)
    question_group.session.questions.where(type: question.type).any?
  end
end
