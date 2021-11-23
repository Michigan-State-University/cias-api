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
    @cat_mh_api = Api::CatMh.new
  end

  attr_reader :user, :user_session_id, :question_id, :answer_params, :cat_mh_api

  def call
    user_session = UserSession.find(user_session_id)

    if user_session.type == 'UserSession::CatMh'
      answer = cat_mh_api.on_user_answer(user_session, question_id, response(answer_params), duration(user_session))
    else
      answer = answer_params[:type].constantize.where(question_id: question_id, user_session_id: user_session_id)
                                   .order(:created_at)
                                   .first_or_initialize(question_id: question_id, user_session_id: user_session_id)
      answer.assign_attributes(answer_params)
      answer.save!
      answer.on_answer
    end

    user_session.on_answer
    user_session.update_user_intervention
    answer
  end

  private

  def duration(user_session)
    last_answer_at = user_session.last_answer_at
    last_answer_at = user_session.created_at if last_answer_at.blank?
    (Time.current - last_answer_at).to_i
  end

  def response(answer_params)
    answer_params['body']['data'].first['value']
  end
end
