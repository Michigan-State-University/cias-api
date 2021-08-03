# frozen_string_literal: true

class V1::AnswerService
  prepend Database::Transactional

  def self.call(user, user_session_id, question_id, answer_params)
    new(user, user_session_id, question_id, answer_params).call
  end

  def initialize(user, user_session_id, question_id, answer_params)
    @user = user
    @user_session_id = user_session_id
    @question_id = question_id
    @answer_params = answer_params
  end

  attr_reader :user, :user_session_id, :question_id, :answer_params

  def call
    user_session = UserSession.find(user_session_id)
    answer = answer_params[:type].constantize.where(question_id: question_id, user_session_id: user_session_id)
                                 .order(:created_at)
                                 .first_or_initialize(question_id: question_id, user_session_id: user_session_id)
    answer.assign_attributes(answer_params)
    answer.save!
    user_session.on_answer
    answer.on_answer
    answer
  end
end
