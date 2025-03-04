# frozen_string_literal: true

class V1::UserSessionsController < V1Controller
  skip_before_action :authenticate_user!, only: %i[create show_or_create]
  before_action :validate_intervention_status

  def show
    validate_session_status
    authorize! :read, UserSession

    user_session = V1::UserSessions::FetchService.call(params[:session_id], current_v1_user.id, params[:health_clinic_id])

    render json: serialized_response(user_session), status: :ok

    user_session.update!(started: true)
    user_session.user_intervention.in_progress!
  end

  def create
    validate_session_status
    user_session = V1::UserSessions::CreateService.call(session_id, user_id, health_clinic_id)
    authorize! :create, user_session
    user_session.save!
    @current_v1_user_or_guest_user.update!(quick_exit_enabled: true) if intervention.quick_exit?

    render json: serialized_response(user_session), status: :ok
  end

  def show_or_create
    validate_session_status
    user_session = V1::UserSessions::FetchOrCreateService.call(session_id, user_id, health_clinic_id)
    authorize! :create, user_session
    user_session.save!
    @current_v1_user_or_guest_user.update!(quick_exit_enabled: true) if intervention.quick_exit?

    render json: serialized_response(user_session), status: :ok
  end

  def quick_exit
    user_session = user_session_load

    authorize! :update, user_session

    user_session.update(quick_exit: true)

    head :ok
  end

  private

  def current_v1_user_or_guest_user
    @current_v1_user_or_guest_user ||= current_v1_user || create_guest_user
  end

  def current_ability
    current_v1_user_or_guest_user.ability
  end

  def create_guest_user
    user = V1::Users::CreateGuest.call
    response.headers.merge!(user.create_new_auth_token)
    user
  end

  def type
    session_load.user_session_type
  end

  def session_load
    Session.find(session_id)
  end

  def user_session_load
    UserSession.find(user_session_id)
  end

  def cat_sessions_in_intervention
    session_load.intervention.sessions.where(type: 'Session::CatMh')
  end

  def user_session_params
    params.require(:user_session).permit(:session_id, :health_clinic_id)
  end

  def session_id
    if params[:action] == 'show'
      params[:session_id]
    else
      user_session_params[:session_id]
    end
  end

  def user_session_id
    params[:user_session_id]
  end

  def intervention
    @intervention = case params[:action]
                    when 'quick_exit'
                      user_session_load.session.intervention
                    when 'show'
                      Session.find(params[:session_id]).intervention
                    else
                      Session.find(session_id).intervention
                    end
  end

  def intervention_id
    intervention.id
  end

  def health_clinic_id
    user_session_params[:health_clinic_id]
  end

  def user_id
    current_v1_user_or_guest_user.id
  end

  def validate_session_status
    return unless session_load.autoclose_enabled

    raise ComplexException.new(I18n.t('sessions.closed'), { reason: 'SESSION_CLOSED' }, :bad_request) if Time.zone.now > session_load.autoclose_at
  end
end
