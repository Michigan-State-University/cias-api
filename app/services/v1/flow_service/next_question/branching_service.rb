# frozen_string_literal: true

class V1::FlowService::NextQuestion::BranchingService
  include FlowServiceHelper
  NO_BRANCHING_TARGET = 'NoBranchingTarget'
  RANDOMIZATION_MISS_MATCH = 'RandomizationMissMatch'
  FORBIDDEN_BRANCHING_TO_CAT_MH_SESSION = 'ForbiddenBranchingToCatMhSession'

  def initialize(question, user_session)
    @last_answered_question = question
    @additional_information = {}
    @user_session = user_session
  end

  attr_accessor :additional_information, :user_session, :last_answered_question

  def call
    return nil if last_answered_question.id.eql?(last_question_in_order.id)

    apply_formula_or_next_question_in_order
  end

  private

  def apply_formula_or_next_question_in_order
    return next_question_in_order if last_answered_question.formulas.blank?

    obj_src = nil
    last_answered_question.formulas.each do |formula|
      obj_src = last_answered_question.exploit_formula(all_var_values, formula['payload'], formula['patterns'])
      break unless obj_src.nil?
    end

    additional_information[:warning] = obj_src if obj_src.is_a?(String)

    branching_question = fetch_target_question(obj_src)
    branching_question || next_question_in_order
  end

  def fetch_target_question(obj_src)
    return next_question_in_order if obj_src.nil?

    branching_question = branching_source_to_question(obj_src) if obj_src.is_a?(Hash)
    mark_answers_as_alternative(branching_question) unless branching_question.nil?

    branching_question
  end

  def branching_source_to_question(source)
    source = V1::RandomizationService.call(source['target'])

    if source.is_a?(Array)
      additional_information[:warning] = RANDOMIZATION_MISS_MATCH
      return nil
    end

    branching_type = source['type']
    question_or_session = branching_type.safe_constantize.find_by(id: source['id'])

    if question_or_session.nil?
      additional_information[:warning] = NO_BRANCHING_TARGET
      return nil
    end

    return nil if branching_type.eql?('Session') && user_session.session.intervention.module_intervention?

    if preview? && question_or_session.type.eql?('Session::CatMh')
      additional_information[:warning] = FORBIDDEN_BRANCHING_TO_CAT_MH_SESSION
      return last_question_in_order
    end

    return question_or_session if branching_type.include? 'Question'

    perform_session_branching(question_or_session)
  end

  def perform_session_branching(session)
    is_session_available_now = session.available_now?(prepare_participant_date_with_schedule_payload(session)) || session.schedule_immediately?
    user_session.finish(send_email: !is_session_available_now)

    return first_question_in_next_session(session) if is_session_available_now && !module_intervention?

    user_session.session.finish_screen
  end

  def module_intervention?
    user_session.session.intervention.module_intervention?
  end

  def first_question_in_next_session(session)
    next_user_session = next_user_session!(session)
    next_user_session.update!(started: true)
    additional_information[:next_user_session_id] = next_user_session.id
    additional_information[:next_session_id] = session.id

    next_user_session.first_question
  end

  def mark_answers_as_alternative(next_question)
    return if next_question.is_a? Hash

    question_ids = next_question.position_lower.pluck(:id)
    user_session.answers.where(draft: true, question_id: question_ids).each do |answer|
      answer.update!(alternative_branch: true)
    end
  end

  def prepare_participant_date_with_schedule_payload(next_session)
    return unless next_session.schedule == 'days_after_date'

    participant_date = all_var_values[next_session.days_after_date_variable_name]
    (participant_date.to_datetime + next_session.schedule_payload&.days) if participant_date
  end

  def all_var_values
    @all_var_values ||= V1::UserInterventionService.new(user_session.user_intervention_id, user_session.id).var_values
  end

  def last_question_in_order
    @last_question_in_order ||=
      (last_answered_question.present? ? last_answered_question.position_equal_or_higher.last : user_session.session.questions.last)
  end

  def next_question_in_order
    @next_question_in_order ||=
      (last_answered_question.present? ? last_answered_question.position_equal_or_higher[1] : user_session.session.questions.first)
  end
end
