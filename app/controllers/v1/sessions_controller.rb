# frozen_string_literal: true

class V1::SessionsController < V1Controller
  include Resource::Clone
  include Resource::Position

  authorize_resource only: %i[create update destroy]

  def index
    render json: serialized_response(sessions_scope)
  end

  def show
    response = serialized_hash(
      session_service.session_load(session_id),
    )
    response = response.merge(reports_size: reports_size)
    render json: response
  end

  def create
    session = session_service.create(session_params)
    render json: serialized_response(session), status: :created
  end

  def update
    session = session_service.update(session_id, session_params)
    render json: serialized_response(session)
  end

  def destroy
    session_service.destroy(session_id)
    head :no_content
  end

  def duplicate
    session = session_service.duplicate(session_id, new_intervention_id)
    render json: serialized_response(session), status: :created
  end

  private

  def session_service
    @session_service ||= V1::SessionService.new(current_v1_user, intervention_id)
  end

  def sessions_scope
    session_service.sessions
  end

  def session_id
    params[:id]
  end

  def intervention_id
    params[:intervention_id]
  end

  def new_intervention_id
    params[:new_intervention_id]
  end

  def session_params
    params.require(:session).permit(:name, :schedule, :schedule_payload, :schedule_at, :position, :intervention_id, narrator: {}, settings: {}, formula: {}, body: {})
  end

  def reports_size
    GeneratedReport.joins(:user_session).where(user_sessions: {session_id: session_id}).size
  end
end
