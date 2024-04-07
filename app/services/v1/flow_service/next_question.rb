# frozen_string_literal: true

class V1::FlowService::NextQuestion
  FORBIDDEN_BRANCHING_TO_CAT_MH_SESSION = 'ForbiddenBranchingToCatMhSession'
  NO_BRANCHING_TARGET = 'NoBranchingTarget'
  RANDOMIZATION_MISS_MATCH = 'RandomizationMissMatch'

  def initialize(user_session)
    @user_session = user_session
    @additional_information = {}
  end

  attr_reader :last_answered_question
  attr_accessor :user_session

  def call(preview_question_id)
    if preview_question_id.present? && user_session.session.draft?
      return user_session.session.questions.includes(%i[image_blob
                                                        image_attachment]).find(preview_question_id)
    end

    @last_answered_question = user_session.last_answer&.question
    return next_or_current_question(user_session.first_question).prepare_to_display if @last_answered_question.nil?

    question = branching_service.call
    question = schedule_service.call(question)

    next_or_current_question(question)
  end

  def additional_information
    branching_service.additional_information
                     .merge(schedule_service.additional_information)
                     .merge(@additional_information)
  end

  private

  def next_or_current_question(question)
    return question if question.is_a?(Hash)

    if user_session.type == 'UserSession::Sms'
      unless question
        user_session.finish
        return question
      end
    end

    if question.type == 'Question::Finish'
      assign_next_session_id(user_session.session.intervention)
      user_session.finish
    end

    return question unless user_session.user.role?('predefined_participant')
    return question unless question.is_a?(Question::ParticipantReport)

    question_group = question.question_group
    question = question_group.questions.find_by(position: (question.position + 1))
    question ||= user_session.session.question_groups.where('position > ?', question_group.position).order(:position).first.questions.order(:position).first
    question
  end

  def assign_next_session_id(intervention)
    return unless intervention.module_intervention?

    next_session = user_session.session.next_session

    next_session = reassign_next_session_for_flexible_intervention(next_session, intervention) if intervention.type == 'Intervention::FlexibleOrder'

    return if next_session.nil?
    return if intervention.type == 'Intervention::FixedOrder' && !next_session.available_now?(prepare_participant_date_with_schedule_payload(next_session))

    @additional_information[:next_session_id] = next_session.id
  end

  def branching_service
    @branching_service ||= V1::FlowService::NextQuestion::BranchingService.new(last_answered_question, user_session)
  end

  def schedule_service
    @schedule_service ||= V1::FlowService::ScheduleService.new(user_session)
  end

  def prepare_participant_date_with_schedule_payload(next_session)
    return unless next_session.schedule == 'days_after_date'

    participant_date = all_var_values[next_session.days_after_date_variable_name]
    (participant_date.to_datetime + next_session.schedule_payload&.days) if participant_date
  end

  def reassign_next_session_for_flexible_intervention(session, intervention)
    return session unless session.nil? || UserSession.exists?(user_id: user_session.user.id, session_id: session.id)

    intervention.sessions.each do |intervention_session|
      return intervention_session unless UserSession.exists?(user_id: user_session.user.id, session_id: intervention_session.id)
    end

    nil
  end

  def all_var_values
    @all_var_values ||= V1::UserInterventionService.new(user_session.user_intervention_id, user_session.id).var_values(true)
  end
end
