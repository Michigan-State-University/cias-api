# frozen_string_literal: true

class V1::UserSessions::QuestionsController < V1Controller
  def index
    authorize! :read, user_session

    next_question = flow_service.user_session_question(preview_question_id)
    response = V1::Question::Response.call(next_question, current_v1_user)

    render json: response
  end

  def previous
    authorize! :read, user_session

    response = V1::UserSessions::PreviousQuestionService.call(user_session, current_question_id)

    render json: response_with_answer(response)
  end

  private

  def flow_service
    V1::FlowService.new(user_session)
  end

  def user_session
    UserSession.find(params[:user_session_id])
  end

  def preview_question_id
    params[:preview_question_id]
  end

  def current_question_id
    params[:current_question_id]
  end

  def response_with_answer(data)
    serialized_hash(data[:question]).merge({ answer: serialized_hash(data[:answer], Answer)[:data] })
  end
end
