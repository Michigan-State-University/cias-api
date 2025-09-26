# frozen_string_literal: true

class V1::SessionService
  def initialize(user, intervention_id)
    @user = user
    @intervention_id = intervention_id
    @intervention = Intervention.accessible_by(user.ability).find(intervention_id)
  end

  attr_reader :user, :intervention_id
  attr_accessor :intervention

  def sessions(include_multiple_sessions = true)
    include_multiple_sessions = ActiveModel::Type::Boolean.new.cast(include_multiple_sessions)

    basic_scope =
      if include_multiple_sessions || include_multiple_sessions.nil?
        intervention.sessions
      else
        intervention.sessions.where(multiple_fill: false)
      end

    basic_scope.order(:position)
  end

  def session_load(id)
    sessions.find(id)
  end

  def create(session_params)
    session = sessions.new(session_params)
    session_type_sms = session.sms_session_type?
    session.assign_google_tts_voice(first_session) unless session_type_sms
    session.current_narrator = intervention.current_narrator unless session_type_sms
    session.position = session_type_sms ? 999_999 : sessions.where.not(type: 'Session::Sms').last&.position.to_i + 1
    session.save!
    session
  end

  def update(session_id, session_params)
    sanitize_estimated_time_param(session_params)
    session = session_load(session_id)
    session.assign_attributes(session_params.except(:cat_tests))
    session_type_sms = session.sms_session_type?
    assign_cat_tests_to_session(session, session_params) unless session_type_sms
    session.integral_update
    session
  end

  def destroy(session_id)
    session_load(session_id).destroy! if intervention.draft?
  end

  def update_all_schedules(schedule_attributes)
    return sessions.order(:position) if schedule_attributes.empty?

    # rubocop:disable Rails/SkipsModelValidations
    intervention.sessions.update_all(schedule_attributes)
    # rubocop:enable Rails/SkipsModelValidations

    sessions.order(:position)
  end

  def duplicate(session_id, new_intervention_id)
    new_intervention = Intervention.accessible_by(user.ability).find(new_intervention_id)
    old_session = session_load(session_id)
    new_position = new_intervention.sessions.order(:position).last&.position.to_i + 1
    new_variable = "duplicated_#{old_session.variable}_#{new_position}"
    Clone::Session.new(old_session,
                       intervention_id: new_intervention.id,
                       clean_formulas: true,
                       variable: new_variable,
                       position: new_position).execute
  end

  private

  def first_session_voice
    first_session&.google_tts_voice
  end

  def first_session
    intervention.sessions.order(:position)&.first
  end

  def same_as_intervention_language?(session_voice)
    voice_name = session_voice.google_tts_language.language_name
    google_lang_name = intervention.google_language.language_name
    # chinese languages are the only ones not following the convention so this check is needed...
    voice_name.include?('Chinese') ? google_lang_name.include?('Chinese') : voice_name.include?(google_lang_name)
  end

  def clear_branching(object, session_id)
    object.formula['patterns'].each do |pattern|
      pattern['target'].each do |target|
        if target['id'].eql?(session_id)
          target['id'] = ''
          object.save!
        end
      end
    end
  end

  def assign_cat_tests_to_session(session, session_params)
    return if session.type != 'Session::CatMh'
    return unless session_params.key?('cat_tests')

    session.cat_mh_test_types.destroy_all

    session_params['cat_tests'].each do |test_id|
      test = CatMhTestType.find(test_id)
      session.cat_mh_test_types << test
    end
  end

  def sanitize_estimated_time_param(params)
    params[:estimated_time] = params[:estimated_time].to_i if params[:estimated_time].present?
  end
end
