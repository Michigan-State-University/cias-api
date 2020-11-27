# frozen_string_literal: true

class V1::SessionsController < V1Controller
  include Resource::Clone
  include Resource::Position

  authorize_resource only: %i[create update]

  def index
    render json: serialized_response(sessions_scope)
  end

  def show
    render json: serialized_response(session_load)
  end

  def create
    session = sessions_scope.new(session_params)
    session.position = sessions_scope.last&.position.to_i + 1
    session.save!
    session.add_user_sessions
    render json: serialized_response(session), status: :created
  end

  def update
    session = session_load
    session.assign_attributes(session_params)
    session.integral_update
    render json: serialized_response(session)
  end

  private

  def sessions_scope
    Intervention.includes(:sessions).accessible_by(current_ability).find(params[:intervention_id]).sessions.order(:position)
  end

  def session_load
    sessions_scope.find(params[:id])
  end

  def session_params
    params.require(:session).permit(:name, :schedule, :schedule_payload, :schedule_at, :position, :intervention_id, narrator: {}, settings: {}, formula: {}, body: {})
  end
end
