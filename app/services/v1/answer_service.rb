# frozen_string_literal: true

class V1::AnswerService
  def initialize(user)
    @user = user
  end

  attr_reader :user

  def create(user_session_id, question_id, answer_params)
    user_session = UserSession.find(user_session_id)

    ActiveRecord::Base.transaction do
      answer = answer_params[:type].constantize.where(question_id: question_id, user_session_id: user_session.id)
                                   .order(:created_at)
                                   .first_or_initialize(question_id: question_id, user_session_id: user_session_id)
      answer.assign_attributes(answer_params)
      answer.save!
      user_session.on_answer
      answer.on_answer
      V1::UserSessions::ChartStatistics::Create.call(user_session)
      answer
    end
  end
end
