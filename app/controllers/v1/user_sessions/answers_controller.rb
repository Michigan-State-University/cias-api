# frozen_string_literal: true

class V1::UserSessions::AnswersController < V1Controller
  def index
    authorize! :index, Answer

    render json: serialized_response(answers_scope)
  end

  def show
    authorize! :read, Answer

    render json: serialized_response(answer_load)
  end

  def create
    raise ActiveRecord::RecordNotSaved, I18n.t('user_sessions.errors.already_finished') if user_session_load.finished_at?

    answer = V1::AnswerService.call(current_v1_user, user_session_id, question_id, answer_params)
    return head answer['status'] if user_session_load.type == 'UserSession::CatMh'

    render json: serialized_response(answer), status: :created
  end

  private

  def user_session_load
    UserSession.find(user_session_id)
  end

  def answers_scope
    Answer.includes(:question, :user_session).accessible_by(current_ability).where(user_session_id: user_session_id)
  end

  def answer_load
    answers_scope.find(params[:id])
  end

  def user_session_id
    params[:user_session_id]
  end

  def answer_params
    params.require(:answer).permit(:type, body: {}).merge(params.permit(:skipped))
  end

  def question_id
    params.require(:question_id)
  end
end
