# frozen_string_literal: true

class V1::FlowService
  def initialize(user_session)
    @user_session = user_session
  end

  attr_accessor :user_session

  def user_session_question(preview_question_id)
    if user_session.type == 'UserSession::CatMh'
      question = cat_mh_next_question.call
    else
      question = next_question_service.call(preview_question_id)
      question = reflection_service.call(question)
      question = question.prepare_to_display(all_var_values) unless question.is_a?(Hash)
    end

    { question: question, answer: answer(question) }
      .merge(cat_mh_next_question.additional_information)
      .merge(next_question_service&.additional_information)
      .merge(reflection_service.additional_information)
  end

  private

  def next_question_service
    @next_question_service ||= V1::FlowService::NextQuestion.new(user_session)
  end

  def reflection_service
    @reflection_service ||= V1::FlowService::ReflectionService.new(user_session)
  end

  def cat_mh_next_question
    @cat_mh_next_question ||= V1::FlowService::CatMh::NextQuestion.new(user_session)
  end

  def all_var_values
    @all_var_values ||= V1::UserInterventionService.new(user_session.user_intervention_id, user_session.id).var_values
  end

  def answer(question)
    return if question.is_a?(Hash)

    user_session.answers.find_by(question_id: question.id)
  end
end
