# frozen_string_literal: true

class V1::UserSessions::QuestionsController < V1Controller
  def index
    authorize! :read, user_session

    next_question = flow_service.user_session_question(preview_question_id)
    return render_error(I18n.t('activerecord.errors.models.intervention.attributes.cat_mh_connection_failed')) if cat_mh_connection_error?(next_question)

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

  def render_error(error)
    render json: { error: error }, status: :bad_request
  end

  def cat_mh_connection_error?(question)
    question['status'] == 400 && question['error'] == 'Request Time-out'
  end
end
