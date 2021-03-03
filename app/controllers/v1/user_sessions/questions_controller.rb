# frozen_string_literal: true

class V1::UserSessions::QuestionsController < V1Controller
  def index
    authorize! :read, user_session
    next_question = V1::FlowService.new(user_session).user_session_question(preview_question_id)
    response = serialized_hash(
      next_question[:question],
      next_question[:question]&.de_constantize_modulize_name || NilClass
    )
    response = response.merge(warning: next_question[:warning]) if next_question[:warning].presence && next_question[:question].session.intervention.draft?
    render json: response
  end

  private

  def user_session
    UserSession.find(params[:user_session_id])
  end

  def preview_question_id
    params[:preview_question_id]
  end
end
