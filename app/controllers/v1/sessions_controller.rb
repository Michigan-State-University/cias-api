# frozen_string_literal: true

class V1::SessionsController < V1Controller
  include Resource::Clone
  include Resource::Position

  authorize_resource only: %i[create update destroy]

  def index
    render json: serialized_response(sessions_scope)
  end

  def show
    render json: serialized_response(session_service.session_load(params[:id]))
  end

  def create
    session = session_service.create(session_params)
    render json: serialized_response(session), status: :created
  end

  def update
    session = session_service.update(params[:id], session_params)
    render json: serialized_response(session)
  end

  def destroy
    session_service.destroy(params[:id])
    head :no_content
  end

  private

  def session_service
    @session_service ||= V1::SessionService.new(current_v1_user, params[:intervention_id])
  end

  def sessions_scope
    session_service.sessions
  end

  def session_params
    params.require(:session).permit(:name, :schedule, :schedule_payload, :schedule_at, :position, :intervention_id, narrator: {}, settings: {}, formula: {}, body: {})
  end
end
