# frozen_string_literal: true

class V1::Question::Create
  def self.call(questions_scope, question_params)
    new(questions_scope, question_params).call
  end

  def initialize(questions_scope, question_params)
    @questions_scope = questions_scope
    @question_params = question_params
  end

  def call
    question = questions_scope.new(question_params)
    question.position = questions_scope.last&.position.to_i + 1
    question.save!
    question
  end

  private

  attr_reader :question_params
  attr_accessor :questions_scope
end
