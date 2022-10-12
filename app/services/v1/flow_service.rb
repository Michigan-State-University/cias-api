# frozen_string_literal: true

class V1::FlowService
  include CatMh::QuestionMapping

  REFLECTION_MISS_MATCH = 'ReflectionMissMatch'
  NO_BRANCHING_TARGET = 'NoBranchingTarget'
  RANDOMIZATION_MISS_MATCH = 'RandomizationMissMatch'
  FORBIDDEN_BRANCHING_TO_CAT_MH_SESSION = 'ForbiddenBranchingToCatMhSession'

  def initialize(user_session)
    @user_session = user_session
    @user = @user_session.user
    @warning = ''
    @next_user_session_id = ''
    @health_clinic_id = user_session.health_clinic_id
    @cat_mh_api = Api::CatMh.new
    @next_session_id = ''
  end

  attr_reader :user
  attr_accessor :user_session, :warning, :next_user_session_id, :health_clinic_id, :next_session_id

  def user_session_question(preview_question_id)
    if user_session.type == 'UserSession::CatMh'
      cat_mh_question = @cat_mh_api.get_next_question(user_session)
      raise_cat_mh_error if cat_mh_question['status'] >= 400

      user_session.finish if cat_mh_question['body']['questionID'] == -1
      question = prepare_question(user_session, cat_mh_question['body'])
    else
      question = question_to_display(preview_question_id)
      question = perform_narrator_reflections(question)
      question = question.prepare_to_display(all_var_values) unless question.is_a?(Hash)

      if !question.is_a?(Hash) && question.type == 'Question::Finish'
        assign_next_session_id(user_session.session.intervention)
        user_session.finish
      end
    end

    { question: question, warning: warning, next_user_session_id: next_user_session_id, next_session_id: next_session_id }
  end

  private

  def assign_next_session_id(intervention)
    return unless intervention.module_intervention?

    next_session = user_session.session.next_session

    next_session = reassign_next_session_for_flexible_intervention(next_session, intervention) if intervention.type == 'Intervention::FlexibleOrder'

    return if next_session.nil?
    return if intervention.type == 'Intervention::FixedOrder' && !next_session.available_now?(prepare_participant_date_with_schedule_payload(next_session))

    self.next_session_id = next_session.id
  end

  def question_to_display(preview_question_id)
    if preview_question_id.present? && user_session.session.draft?
      return user_session.session.questions.includes(%i[image_blob
                                                        image_attachment]).find(preview_question_id)
    end

    last_answered_question = user_session.last_answer&.question

    return user_session.first_question.prepare_to_display if last_answered_question.nil?

    perform_branching_to_next_question(last_answered_question)
  end

  def perform_branching_to_next_question(last_question)
    return nil if last_question.id.eql?(last_question.position_equal_or_higher.last.id)

    next_question = last_question.position_equal_or_higher[1]
    if last_question.formulas.present?
      obj_src = nil
      last_question.formulas.each do |formula|
        obj_src = last_question.exploit_formula(all_var_values, formula['payload'], formula['patterns'])
        break unless obj_src.nil?
      end
      self.warning = obj_src if obj_src.is_a?(String)
      unless obj_src.nil?
        branching_question = nil
        branching_question = branching_source_to_question(obj_src) if obj_src.is_a?(Hash)
        next_question = branching_question unless branching_question.nil?
      end
    end

    return next_question if next_question.is_a?(Hash)

    next_question.prepare_to_display(all_var_values)
  end

  def branching_source_to_question(source)
    source = V1::RandomizationService.call(source['target'])

    if source.is_a?(Array)
      self.warning = RANDOMIZATION_MISS_MATCH
      return nil
    end

    branching_type = source['type']
    question_or_session = branching_type.safe_constantize.find_by(id: source['id'])

    if question_or_session.nil?
      self.warning = NO_BRANCHING_TARGET
      return nil
    end

    return nil if branching_type.eql?('Session') && user_session.session.intervention.module_intervention?

    if preview? && question_or_session.type.eql?('Session::CatMh')
      self.warning = FORBIDDEN_BRANCHING_TO_CAT_MH_SESSION
      return user_session.session.questions.last
    end
    return question_or_session if branching_type.include? 'Question'

    perform_session_branching(question_or_session)
  end

  def perform_session_branching(session)
    session_available_now = session.available_now?(prepare_participant_date_with_schedule_payload(session))

    user_session.finish(send_email: !session_available_now)

    is_module_intervention = user_session.session.intervention.module_intervention?
    return first_question_in_next_session(session) if session_available_now && !is_module_intervention

    if session_available_now
      next_user_session = UserSession.find_or_initialize_by(session_id: question_or_session.id, user_id: user.id, health_clinic_id: health_clinic_id,
                                                            type: question_or_session.user_session_type)
      next_user_session.save!
      user_session.answers.last.update!(next_session_id: question_or_session.id)
      self.next_user_session_id = next_user_session.id

      return next_user_session.first_question
    end

    user_session.session.finish_screen
  end

  def first_question_in_next_session(session)
    next_user_session = UserSession.find_or_initialize_by(session_id: session.id, user_id: user.id, health_clinic_id: health_clinic_id,
                                                          type: session.user_session_type, user_intervention: user_session.user_intervention)
    next_user_session.save!
    user_session.answers.last.update!(next_session_id: session.id)
    self.next_user_session_id = next_user_session.id

    next_user_session.first_question
  end

  def perform_narrator_reflections(question)
    return question if question.is_a?(Hash)

    question = question.swap_name_mp3(name_audio, name_answer)
    question.narrator['blocks']&.each_with_index do |block, index|
      next unless %w[Reflection ReflectionFormula].include?(block['type'])

      question.narrator['blocks'][index]['target_value'] = prepare_block_target_value(question, block)
    end
    question
  end

  def prepare_block_target_value(question, block)
    return question.exploit_formula(all_var_values, block['payload'], block['reflections']) if block['type'].eql?('ReflectionFormula')

    matched_reflections = []
    block['reflections'].each do |reflection|
      if reflection['variable'].eql?('') || reflection['value'].eql?('')
        self.warning = REFLECTION_MISS_MATCH
        return []
      end

      matched_reflections.push(reflection) if all_var_values.key?(reflection['variable']) && all_var_values[reflection['variable']].eql?(reflection['value'])
    end
    matched_reflections
  end

  def reassign_next_session_for_flexible_intervention(session, intervention)
    return session unless session.nil? || UserSession.exists?(user_id: user.id, session_id: session.id)

    intervention.sessions.each do |intervention_session|
      return intervention_session unless UserSession.exists?(user_id: user.id, session_id: intervention_session.id)
    end

    nil
  end

  def prepare_participant_date_with_schedule_payload(next_session)
    return unless next_session.schedule == 'days_after_date'

    participant_date = all_var_values[next_session.days_after_date_variable_name]
    (participant_date.to_datetime + next_session.schedule_payload&.days) if participant_date
  end

  def raise_cat_mh_error
    error_message = {
      title: I18n.t('activerecord.errors.models.intervention.attributes.cat_mh_connection_failed.title'),
      body: I18n.t('activerecord.errors.models.intervention.attributes.cat_mh_connection_failed.body'),
      button: I18n.t('activerecord.errors.models.intervention.attributes.cat_mh_connection_failed.button')
    }
    raise CatMh::ConnectionFailedException, error_message.to_json
  end

  def all_var_values
    @all_var_values ||= V1::UserInterventionService.new(
      user.id, user_session.session.intervention_id, user_session.id
    ).var_values
  end

  def name_audio
    user_session.name_audio
  end

  def name_answer
    user_session.search_var('.:name:.')
  end

  def preview?
    user_session.session.intervention.draft?
  end
end
