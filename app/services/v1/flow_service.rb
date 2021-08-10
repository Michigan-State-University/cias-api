# frozen_string_literal: true

class V1::FlowService
  REFLECTION_MISS_MATCH = 'ReflectionMissMatch'
  NO_BRANCHING_TARGET = 'NoBranchingTarget'
  RANDOMIZATION_MISS_MATCH = 'RandomizationMissMatch'

  def initialize(user_session)
    @user_session = user_session
    @user = @user_session.user
    @warning = ''
    @next_user_session_id = ''
    @health_clinic_id = user_session.health_clinic_id
  end

  attr_reader :user
  attr_accessor :user_session, :warning, :next_user_session_id, :health_clinic_id

  def user_session_question(preview_question_id)
    question = question_to_display(preview_question_id)
    question = perform_narrator_reflections(question)
    question = prepare_questions_with_answer_values(question)
    question.another_or_feedback(question, all_var_values)

    user_session.finish if question.type == 'Question::Finish'

    { question: question, warning: warning, next_user_session_id: next_user_session_id }
  end

  private

  def question_to_display(preview_question_id)
    return user_session.session.questions.find(preview_question_id) if preview_question_id.present? && user_session.session.draft?

    last_answered_question = user_session.last_answer&.question
    return user_session.session.first_question if last_answered_question.nil?

    perform_branching_to_next_question(last_answered_question)
  end

  def perform_branching_to_next_question(last_question)
    return nil if last_question.id.eql?(last_question.position_equal_or_higher.last.id)

    next_question = last_question.position_equal_or_higher[1]
    if last_question.formula['payload'].present?

      obj_src = last_question.exploit_formula(all_var_values)
      self.warning = obj_src if obj_src.is_a?(String)

      branching_question = branching_source_to_question(obj_src) if obj_src.is_a?(Hash)
      next_question = branching_question unless branching_question.nil?
    end

    next_question
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
    return question_or_session if branching_type.include? 'Question'

    session_available_now = question_or_session.available_now?(prepare_participant_date_with_schedule_payload(question_or_session))

    user_session.finish(send_email: !session_available_now)

    if session_available_now
      next_user_session = UserSession.find_or_initialize_by(session_id: question_or_session.id, user_id: user.id, health_clinic_id: health_clinic_id)
      next_user_session.save!
      self.next_user_session_id = next_user_session.id
      return question_or_session.first_question
    end

    user_session.session.finish_screen
  end

  def perform_narrator_reflections(question)
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

  def prepare_questions_with_answer_values(question)
    question.another_or_feedback(question, all_var_values)
  end

  def prepare_participant_date_with_schedule_payload(next_session)
    return unless next_session.schedule == 'days_after_date'

    participant_date = all_var_values[next_session.days_after_date_variable_name]
    (participant_date.to_datetime + next_session.schedule_payload&.days) if participant_date
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
end
