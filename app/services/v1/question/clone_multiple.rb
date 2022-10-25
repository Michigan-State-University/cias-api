# frozen_string_literal: true

class V1::Question::CloneMultiple
  def self.call(question_ids, chosen_questions)
    new(question_ids, chosen_questions).call
  end

  def initialize(question_ids, chosen_questions)
    @question_ids = question_ids
    @questions = chosen_questions
  end

  def call
    raise ActiveRecord::RecordNotFound unless proper_questions?(questions, question_ids)
    raise ActiveRecord::ActiveRecordError if inconsistent_questions?(questions)

    ActiveRecord::Base.transaction do
      existed_question_group = questions.first&.question_group
      question_group = if duplicate_to_existed_question_group?(questions, existed_question_group)
                         existed_question_group
                       else
                         question_groups = questions.first.session.question_groups
                         position = question_groups.where.not(type: 'QuestionGroup::Finish').last&.position.to_i + 1
                         question_groups.create!(title: 'Copied Questions', position: position, type: question_group_type)
                       end

      clone_questions(questions, question_group)
    end
  end

  private

  def inconsistent_questions?(questions)
    return true if (questions.tlfb.any? && questions.without_tlfb.any?) || (questions.tlfb.any? && incorrect_tlfb_group?(questions))

    false
  end

  def incorrect_tlfb_group?(questions)
    questions.count != 3 || (
      questions.where(type: 'Question::TlfbConfig').blank? ||
      questions.where(type: 'Question::TlfbEvents').blank? ||
      questions.where(type: 'Question::TlfbQuestion').blank?
    )
  end

  def question_group_type
    questions.tlfb.any? ? 'QuestionGroup::Tlfb' : 'QuestionGroup::Plain'
  end

  def proper_questions?(questions, question_ids)
    question_ids && questions.size == question_ids.size
  end

  def duplicate_to_existed_question_group?(questions, question_group)
    return false if question_group.type.eql? 'QuestionGroup::Tlfb'

    questions.all? { |question| question.question_group_id.eql?(question_group.id) }
  end

  def clone_questions(questions, question_group)
    question_group_questions = question_group.questions

    questions.each do |question|
      if question_type_must_be_unique(question)
        raise ActiveRecord::RecordNotUnique,
              (I18n.t 'activerecord.errors.models.question_group.question',
                      question_type: question.type)
      end

      cloned = question.clone
      cloned.position = question_group_questions.last&.position.to_i + 1
      question_group_questions << cloned
    end

    question_group_questions.last(questions.size)
  end

  def question_type_must_be_unique(question)
    question.type.in?(Question::UNIQUE_IN_SESSION)
  end

  attr_reader :question_ids
  attr_accessor :questions
end
