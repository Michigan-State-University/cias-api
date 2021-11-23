# frozen_string_literal: true

class V1::Question::Response
  include Resource

  def self.call(next_question)
    new(next_question).call
  end

  def initialize(next_question)
    @next_question = next_question
  end

  def call
    if next_question[:question].is_a?(Hash)
      response = next_question[:question]
      response[:warning] = next_question[:warning] if next_question[:warning].present?
      response[:next_user_session_id] = next_question[:next_user_session_id]
      response[:next_session_id] = next_question[:next_session_id] if next_question.key?(:next_session_id)
      response
    else
      response = serialized_hash(
        next_question[:question],
        next_question[:question]&.de_constantize_modulize_name || NilClass
      )
      response = add_information(response, :warning, next_question) if next_question[:question].session.intervention.draft?
      response = add_information(response, :next_user_session_id, next_question)
      add_information(response, :next_session_id, next_question)
    end
  end

  private

  def add_information(response, key, next_question)
    response = response.merge(key => next_question[key]) if next_question[key].presence
    response
  end

  attr_accessor :next_question
end
