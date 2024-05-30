# frozen_string_literal: true

class V1::SessionsController < V1Controller
  include Resource::Position

  def index
    authorize! :index, Session

    render json: serialized_response(sessions_scope)
  end

  def show
    authorize! :read, Session
    authorize! :read, session_load

    render json: serialized_response(session_load)
  end

  def create
    authorize! :create, Session
    authorize! :create, intervention

    return head :forbidden unless intervention.ability_to_update_for?(current_v1_user)

    session = session_service.create(session_params_for_create)
    render json: serialized_response(session), status: :created
  end

  def update
    authorize! :update, Session
    authorize! :update, session_load

    return head :forbidden unless session_load.ability_to_update_for?(current_v1_user)

    session = session_service.update(session_id, session_params)
    render json: serialized_response(session)
  end

  def destroy
    authorize! :destroy, Session

    return head :forbidden unless session_load.ability_to_update_for?(current_v1_user)

    session_service.destroy(session_id)
    head :no_content
  end

  def duplicate
    authorize! :duplicate, Session

    DuplicateJobs::Session.perform_later(current_v1_user, session_id, new_intervention_id)
    render status: :ok
  end

  def clone
    authorize! :clone, Session
    authorize! :update, session_obj

    return head :forbidden unless session_obj.ability_to_update_for?(current_v1_user)

    CloneJobs::Session.perform_later(current_v1_user, session_obj)

    render status: :ok
  end

  def session_variables
    authorize! :read, Session

    variable_names = session_obj.fetch_variables(variable_filter_options)

    render json: { session_variable: session_obj.variable, variable_names: variable_names }
  end

  def reflectable_questions
    authorize! :read, Session

    questions = session_obj.questions.where(type: %w[Question::Grid Question::Multiple Question::Single])

    render json: serialized_response(questions, 'ReflectableQuestion')
  end

  private

  def variable_filter_options
    params.permit(:only_digit_variables, :question_id, :include_current_question, allow_list: [])
  end

  def session_service
    @session_service ||= V1::SessionService.new(current_v1_user, intervention_id)
  end

  def session_load
    @session_load ||= session_service.session_load(session_id)
  end

  def sessions_scope
    session_service.sessions(params[:include_multiple_sessions])
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
                                    :intervention_id, :days_after_date_variable_name, :google_tts_voice_id, :multiple_fill,
                                    :cat_mh_language_id, :cat_mh_time_frame_id, :cat_mh_population_id, :estimated_time,
                                    :autofinish_enabled, :autofinish_delay, :autoclose_enabled, :autoclose_at,
                                    :welcome_message, :default_response,
                                    narrator: {}, settings: {}, sms_codes_attributes: %i[id sms_code],
                                    formulas: [
                                      :payload, { patterns: [:match, {
                                        target: %i[type probability id]
                                      }] }
                                    ], cat_tests: [])
  end

  def intervention
    @intervention ||= Intervention.find(params[:intervention_id])
  end

  def session_params_for_create
    session_params.except(:cat_tests)
  end
end
