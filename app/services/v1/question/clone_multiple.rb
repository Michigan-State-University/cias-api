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

    ActiveRecord::Base.transaction do
      question_group_id = questions.first&.question_group_id
      question_group = if all_questions_from_one_question_group?(questions, question_group_id)
                         questions.first&.question_group
                       else
                         question_groups = questions.first.session.question_groups
                         position = question_groups.where(type: 'QuestionGroup::Plain').last&.position.to_i + 1
                         question_groups.create!(title: 'Copied Questions', position: position)
                       end

      clone_questions(questions, question_group)
    end
  end

  private

  def proper_questions?(questions, question_ids)
    question_ids && questions.size == question_ids.size
  end

  def all_questions_from_one_question_group?(questions, question_group_id)
    questions.all? { |question| question.question_group_id.eql?(question_group_id) }
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
    [::Question::Name, ::Question::ParticipantReport, ::Question::ThirdParty, ::Question::Phone].member? question.class
  end

  attr_reader :question_ids
  attr_accessor :questions
end
