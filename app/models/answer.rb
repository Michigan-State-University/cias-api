# frozen_string_literal: true

class Answer < ApplicationRecord
  include BodyInterface
  include FormulaInterface
  belongs_to :user, optional: true
  belongs_to :question, inverse_of: :answers

  delegate :subclass_name, :settings, :order, :title, :subtitle, :formula, to: :question, allow_nil: true

  validate :type_integrity_validator

  def retrive_previous_answers
    Answer.where(question_id: question.questions_order_up_to_equal.ids, user_id: user_id)
  end

  def collect_variables
    retrive_previous_answers.each_with_object({}) do |collection, hash|
      collection.body_data.each do |obj|
        hash[obj['variable']['name']] = obj['variable']['value']
      end
    end
  end

  private

  def type_integrity_validator
    return if type.demodulize.eql? subclass_name

    errors.add(:type, 'broken type integrity')
  end
end
