# frozen_string_literal: true

class V1::SessionService
  def initialize(user, intervention_id)
    @user = user
    @intervention_id = intervention_id
    @intervention = Intervention.includes(:sessions).accessible_by(user.ability).find(intervention_id)
  end

  attr_reader :user, :intervention_id
  attr_accessor :intervention

  def sessions
    intervention.sessions.order(:position)
  end

  def session_load(id)
    sessions.find(id)
  end

  def create(session_params)
    session = sessions.new(session_params)
    apply_narrator_settings(session)
    session.position = sessions.last&.position.to_i + 1
    session.save!
    session
  end

  def update(session_id, session_params)
    session = session_load(session_id)
    session.assign_attributes(session_params.except(:cat_tests))
    assign_cat_tests_to_session(session, session_params)
    session.integral_update
    session
  end

  def destroy(session_id)
    session_load(session_id).destroy! if intervention.draft?
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

  def same_as_intervention_language(session_voice)
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

  def apply_narrator_settings(session)
    first = first_session
    if first.nil? && session.type.eql?('Session::CatMh')
      session.cat_mh_language = CatMhLanguage.find_by(name: intervention.google_language.language_name) || CatMhLanguage.find_by(name: 'English')
      session.google_tts_voice = session.cat_mh_language.google_tts_voices.first
      return
    end
    first_session_voice_settings = first&.google_tts_voice
    return unless first_session_voice_settings.present? && same_as_intervention_language(first_session_voice_settings)

    session.google_tts_voice = first_session_voice_settings
    session.cat_mh_language = CatMhLanguage.find_by(name: intervention.google_language.language_name) if session.type.eql? 'Session::CatMh'
  end
end
