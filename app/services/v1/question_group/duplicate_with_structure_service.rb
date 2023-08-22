# frozen_string_literal: true

class V1::QuestionGroup::DuplicateWithStructureService
  SKIPPABLE_QUESTIONS = %w[Question::HenryFordInitial].freeze

  def self.call(session, selected_groups_with_questions)
    new(session, selected_groups_with_questions).call
  end

  def initialize(session, selected_groups_with_questions)
    raise ArgumentError, I18n.t('duplication_with_structure.wrong_argument') if selected_groups_with_questions.blank?

    @session = session
    @question_groups_with_specific_questions = selected_groups_with_questions
  end

  def call
    result = nil
    ActiveRecord::Base.transaction do
      result = duplicate_question_groups_to_session(session)
    end

    result
  end

  attr_accessor :session
  attr_reader :question_groups_with_specific_questions

  private

  def duplicate_question_groups_to_session(session)
    question_groups_with_specific_questions.map do |question_group|
      selected_group = QuestionGroup.find(question_group['id'])
      new_question_group = create_new_group_in_session(session, selected_group)
      create_selected_questions_and_assign_to_group(selected_group, question_group['question_ids'], new_question_group)
      confirm_questions_presence!(new_question_group.reload)
    end
  end

  def create_new_group_in_session(session, selected_group)
    position = session.question_groups.where.not(type: 'QuestionGroup::Finish').last&.position.to_i + 1
    QuestionGroup.create(session_id: session.id, title: I18n.t('duplication_with_structure.question_group_title', source_group_title: selected_group.title),
                         position: position, type: selected_group.type)
  end

  def create_selected_questions_and_assign_to_group(selected_group, question_ids, question_group)
    position = question_group.questions.count + 1
    question_ids.each do |question_id|
      question = selected_group.questions.find(question_id)
      session = question_group.session
      next if skip_question?(question, session.intervention)

      validate_uniqueness_of_question(question, session)

      question_group.questions << Clone::Question.new(question, clean_formulas: true, position: position).execute
      position += 1
    end
  end

  def load_sessions(target_session_ids)
    sessions = Session.where(id: target_session_ids)

    raise ArgumentError, I18n.t('duplication_with_structure.wrong_sessions') if sessions.count != target_session_ids.size

    sessions
  end

  def validate_uniqueness_of_question(question, session)
    return unless question.type.in?(Question::UNIQUE_IN_SESSION)

    raise ArgumentError, I18n.t('duplication_with_structure.uniqueness_violation') if uniq_question_already_in_session(question, session)
    raise ArgumentError, I18n.t('duplication_with_structure.hfhs.uniqueness_violation') unless validate_hfhs_access_and_uniqueness(question,
                                                                                                                                   session.intervention)
  end

  def uniq_question_already_in_session(question, session)
    session.questions.where(type: question.type).any? && question.type.in?(Question::UNIQUE_IN_SESSION)
  end

  def validate_hfhs_access_and_uniqueness(question, intervention)
    return true unless question.type.eql?('Question::HenryFordInitial')
    return false unless intervention.hfhs_access?

    intervention.hfhs_access? && session.questions.where(type: question.type).blank?
  end

  def confirm_questions_presence!(question_group)
    return question_group unless question_group.questions.empty?

    question_group.destroy!
    raise ArgumentError, I18n.t('duplication_with_structure.wrong_package')
  end

  def skip_question?(question, intervention)
    question.type.in?(SKIPPABLE_QUESTIONS) && !intervention.hfhs_access?
  end
end
