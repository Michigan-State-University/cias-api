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
      response[:next_user_session_id] = next_question[:next_user_session_id] if next_question[:next_user_session_id].present?
      response[:next_session_id] = next_question[:next_session_id] if next_question.key?(:next_session_id)
    else
      response = serialized_hash(
        next_question[:question],
        next_question[:question]&.de_constantize_modulize_name || NilClass
      )
      response = add_information(response, :warning, next_question) if next_question[:question].session.intervention.draft?
      %i[next_user_session_id next_session_id].each do |key|
        response = add_information(response, key, next_question)
      end
      response = response.merge(answer: serialized_hash(next_question[:answer], Answer)[:data])
    end
    response
  end

  private

  def add_information(response, key, next_question)
    response = response.merge(key => next_question[key]) if next_question[key].presence
    response
  end

  attr_accessor :next_question
end
