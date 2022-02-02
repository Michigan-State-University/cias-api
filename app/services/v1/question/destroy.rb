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
    raise ActiveRecord::ActiveRecordError if not_all_tlfb_group?

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

  def not_all_tlfb_group?
    return false unless chosen_questions.pluck(:type).any? {|type| type.include?('Tlfb')}

    tlfb_questions = chosen_questions.where("type like ?", "%Tlfb%")

    return true if (tlfb_questions.pluck(:question_group_id).uniq.count * 3) != tlfb_questions.count

    false
  end

  def proper_questions?
    question_ids && chosen_questions.size == question_ids.size
  end

  attr_reader :question_ids
  attr_accessor :chosen_questions
end
