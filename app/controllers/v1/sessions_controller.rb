# frozen_string_literal: true

class V1::SessionsController < V1Controller
  include Resource::Position

  def index
    authorize! :index, Session

    render json: serialized_response(sessions_scope)
  end

  def show
    authorize! :read, Session

    render json: serialized_response(session_service.session_load(session_id))
  end

  def create
    authorize! :create, Session

    session = session_service.create(session_params)
    render json: serialized_response(session), status: :created
  end

  def update
    authorize! :update, Session

    session = session_service.update(session_id, session_params)
    render json: serialized_response(session)
  end

  def destroy
    authorize! :destroy, Session

    session_service.destroy(session_id)
    head :no_content
  end

  def duplicate
    authorize! :duplicate, Session

    session = session_service.duplicate(session_id, new_intervention_id)
    render json: serialized_response(session), status: :created
  end

  def clone
    authorize! :clone, Session

    intervention = session_obj.intervention
    position = intervention.sessions.order(:position).last.position + 1
    params = { variable: "cloned_#{session_obj.variable}_#{position}" }
    cloned_resource = Session.find(session_id).clone(params: params)
    render json: serialized_response(cloned_resource), status: :created
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

  def session_obj
    @session_obj ||= Session.accessible_by(current_ability).find(session_id)
  end

  def intervention_id
    params[:intervention_id]
  end

  def new_intervention_id
    params[:new_intervention_id]
  end

  def session_params
    params.require(:session).permit(:name, :schedule, :schedule_payload, :schedule_at, :position, :variable, :type,
                                    :intervention_id, :days_after_date_variable_name, :google_tts_voice_id, narrator: {}, settings: {},
                                                                                                            formula: {})
  end
end
