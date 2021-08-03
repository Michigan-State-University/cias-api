# frozen_string_literal: true

class V1::QuestionGroup::QuestionsChangeService
  attr_accessor :question_group, :questions

  def self.call(question_group, questions)
    new(question_group, questions).call
  end

  def initialize(question_group, questions)
    @question_group = question_group
    @questions = questions
  end

  def call
    questions.update_all(question_group_id: question_group.id) # rubocop:disable Rails/SkipsModelValidations
    question_group.reload
  end
end
