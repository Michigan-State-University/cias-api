# frozen_string_literal: true

class V1::Question::Create
  def self.call(question_group, question_params)
    new(question_group, question_params).call
  end

  def initialize(question_group, question_params)
    @question_group = question_group
    @questions_scope = question_group.questions.order(:position)
    @question_params = question_params
  end

  def call
    raise raise ActiveRecord::ActiveRecordError if question_group.type.eql?('QuestionGroup::Tlfb')

    question = questions_scope.new(question_params)
    question.position = questions_scope.last&.position.to_i + 1
    question.save!
    question
  end

  private

  attr_reader :question_params, :question_group
  attr_accessor :questions_scope
end
