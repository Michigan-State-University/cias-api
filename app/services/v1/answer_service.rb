# frozen_string_literal: true

class V1::AnswerService
  def initialize(user)
    @user = user
  end

  attr_reader :user

  def create(question_id, answer_params)
    question = Question.find(question_id)
    user_session = UserSession.find_or_create_by!(session_id: question.session.id, user_id: user.id)
    # job 24h do zakonczenia sesji
    answer = Answer.where(question_id: question_id, user_session_id: user_session.id)
                   .order(:created_at)
                   .first_or_initialize(question_id: question_id, user_session_id: user_session.id)
    answer.assign_attributes(answer_params)
    answer.save!
    answer
  end
end
