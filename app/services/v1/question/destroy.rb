# frozen_string_literal: true

class V1::Question::Destroy
  def self.call(chosen_questions, question_ids)
    new(chosen_questions, question_ids).call
  end

  def initialize(chosen_questions, question_ids)
    @chosen_questions = chosen_questions
    @question_ids = question_ids
  end

  def call
    raise ActiveRecord::RecordNotFound unless proper_questions?

    Question.transaction do
      chosen_questions.each do |question|
        question_group = question.question_group
        question.destroy!
        qg = question.question_group
        qg.destroy! if question_group.questions.empty?
      end
    end
  end

  private

  def proper_questions?
    question_ids && chosen_questions.size == question_ids.size
  end

  attr_reader :question_ids
  attr_accessor :chosen_questions
end
