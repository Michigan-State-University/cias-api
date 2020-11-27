# frozen_string_literal: true

class Answer < ApplicationRecord
  include BodyInterface

  belongs_to :user, optional: true
  belongs_to :question, inverse_of: :answers

  attribute :body, :json, default: { data: [] }

  delegate :subclass_name, :settings, :position, :title, :subtitle, :formula, to: :question, allow_nil: true

  validate :type_integrity_validator

  scope :user_answers, lambda { |user_id, session_ids|
    relation = joins(question: :question_group).where(user_id: user_id)
    relation.where('question_groups.session_id IN(?)', session_ids.join(',')) if session_ids.any?
    relation
  }

  def retrive_previous_answers
    previous_sessions_ids = question.session.intervention.sessions.where('sessions.position < ?', question.session.position).ids
    previous_answers = Answer.user_answers(user_id, previous_sessions_ids)
    current_answers = Answer.joins(question: :question_group).where(questions: { position: ..question.position }).user_answers(user_id, [question.session.id])

    previous_answers + current_answers
  end

  def collect_var_values
    retrive_previous_answers.each_with_object({}) do |collection, hash|
      collection.body_data.each do |obj|
        hash[obj['var']] = obj['value']
      end
    end
  end

  def perform_response
    question.next_session_or_question(collect_var_values)
  end

  private

  def type_integrity_validator
    return if type.demodulize.eql? subclass_name

    errors.add(:type, 'broken type integrity')
  end
end
