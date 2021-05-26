# frozen_string_literal: true

class V1::UserSessions::QuestionsController < V1Controller
  def index
    authorize! :read, user_session
    next_question = V1::FlowService.new(user_session).user_session_question(preview_question_id)
    response = serialized_hash(
      next_question[:question],
      next_question[:question]&.de_constantize_modulize_name || NilClass
    )
    if next_question[:question].session.intervention.draft?
      response = add_information(response, :warning,
                                 next_question)
    end
    response = add_information(response, :next_user_session_id, next_question)
    render json: response
  end

  private

  def user_session
    UserSession.find(params[:user_session_id])
  end

  def preview_question_id
    params[:preview_question_id]
  end

  def add_information(response, key, next_question)
    response = response.merge(key => next_question[key]) if next_question[key].presence
    response
  end
end
