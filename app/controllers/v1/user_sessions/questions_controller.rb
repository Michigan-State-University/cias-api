# frozen_string_literal: true

class V1::UserSessions::QuestionsController < V1Controller
  def index
    authorize! :read, user_session

    next_question = flow_service.user_session_question(preview_question_id)
    response = V1::Question::Response.call(next_question)

    render json: response
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
end
