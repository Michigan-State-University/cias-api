# frozen_string_literal: true

class Answer < ApplicationRecord
  include BodyInterface
  include FormulaInterface
  belongs_to :user, optional: true
  belongs_to :question, inverse_of: :answers

  attribute :body, :json, default: { data: [] }

  delegate :subclass_name, :settings, :position, :title, :subtitle, :formula, to: :question, allow_nil: true

  validate :type_integrity_validator
  validates :type, uniqueness: { scope: %i[user question] }, unless: -> { user.role?('researcher') }

  def retrive_previous_answers
    Answer.where(question_id: question.questions_position_up_to_equal.ids, user_id: user_id)
  end

  def collect_variables
    retrive_previous_answers.each_with_object({}) do |collection, hash|
      collection.body_data.each do |obj|
        hash[obj['var']] = obj['value']
      end
    end
  end

  def processing_answering
    if question.id.eql?(question.questions_position_up_to_equal.last.id)
      nil
    elsif question.formula['payload'].present?
      pointo_to = exploit_patterns
      pointo_to['target']['type'].safe_constantize.find(pointo_to['target']['id'])
    else
      next_question = question.questions_position_up_to_equal[1]
      return next_question unless next_question.type.eql?('Question::Feedback')

      next_question.body['target_value']['target_value'] = exploit_patterns
      next_question
    end
  end

  private

  def type_integrity_validator
    return if type.demodulize.eql? subclass_name

    errors.add(:type, 'broken type integrity')
  end
end
