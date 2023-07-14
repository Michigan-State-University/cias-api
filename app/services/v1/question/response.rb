# frozen_string_literal: true

class V1::Question::Response
  include Resource

  def self.call(next_question, current_user)
    new(next_question, current_user).call
  end

  def initialize(next_question, current_user)
    @next_question = next_question
    @current_user = current_user
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
      require 'pry'; binding.pry
      response = response.merge(answer: serialized_hash(next_question[:answer], Answer)[:data])
      response = response.merge(hfhs_patient_detail: {}) if next_question[:question].is_a? Question::HenryFordInitial
    end
    response
  end

  private

  def add_information(response, key, next_question)
    response = response.merge(key => next_question[key]) if next_question[key].presence
    response
  end

  attr_accessor :next_question
  attr_reader :current_user
end
