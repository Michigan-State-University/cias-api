# frozen_string_literal: true

class V1::UserSessions::QuestionsController < V1Controller
  def index
    next_question = V1::FlowService.new(user_session_id).next_question
    response = serialized_hash(
      next_question[:question],
      next_question[:question]&.de_constantize_modulize_name || NilClass
    )
    response = response.merge(warning: next_question[:warning]) if next_question[:warning].presence && next_question[:question].session.intervention.draft?
    render json: response
  end

  private

  def user_session_id
    params[:user_session_id]
  end
end
