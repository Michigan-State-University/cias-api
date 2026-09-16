# frozen_string_literal: true

class V1::Intervention::PredefinedParticipants::BulkImportService
  # Do NOT `prepend Database::Transactional` — would collapse per-row transactions into one batch savepoint.
  QUESTION_TO_ANSWER = {
    'Question::Single' => Answer::Single,
    'Question::Number' => Answer::Number,
    'Question::Date' => Answer::Date
  }.freeze

  def self.call(researcher, intervention, payload)
    new(researcher, intervention, payload).call
  end

  def initialize(researcher, intervention, payload)
    @researcher = researcher
    @intervention = intervention
    @payload = payload
    @result = {
      total: payload.size,
      participants_created: 0,
      ra_completed: 0,
      ra_partial: 0,
      failed: 0
    }
  end

  def call
    @payload.each { |entry| process_entry(entry) }
    @result
  end

  private

  attr_reader :researcher, :intervention, :payload

  def ra_session
    return @ra_session if defined?(@ra_session)

    @ra_session = intervention.sessions.find_by(type: 'Session::ResearchAssistant')
  end

  def question_lookup
    @question_lookup ||= ra_session ? build_question_lookup : {}
  end

  def build_question_lookup
    ra_session.questions.each_with_object({}) do |question, lookup|
      question.question_variables.compact_blank.each { |var| lookup[var] = question }
    end
  end

  def process_entry(entry)
    attrs = entry['attributes']
    variable_answers = entry['variable_answers'] || {}
    ra_outcome = nil

    ActiveRecord::Base.transaction do
      user = create_participant!(attrs)
      ra_outcome = import_ra_answers(user, variable_answers) if variable_answers.any?
    end

    @result[:participants_created] += 1
    case ra_outcome
    when :completed then @result[:ra_completed] += 1
    when :partial   then @result[:ra_partial]   += 1
    end
  rescue ActiveRecord::RecordNotUnique
    # Expected race (concurrent imports on same email / UserSession::RA) — do not page Sentry.
    @result[:failed] += 1
  rescue StandardError => e
    Sentry.capture_exception(e)
    @result[:failed] += 1
  end

  def create_participant!(attrs)
    V1::Intervention::PredefinedParticipants::CreateService.call(
      intervention,
      ActionController::Parameters.new(attrs).permit!
    )
  end

  def import_ra_answers(user, variable_answers)
    raise 'intervention has no RA session' if ra_session.blank?

    pup = user.predefined_user_parameter

    user_intervention = UserIntervention.find_or_create_by!(
      user_id: user.id,
      intervention_id: intervention.id,
      health_clinic_id: pup.health_clinic_id
    )

    user_session = UserSession::ResearchAssistant.find_or_create_by!(
      session_id: ra_session.id,
      user_id: user.id,
      type: 'UserSession::ResearchAssistant',
      user_intervention_id: user_intervention.id,
      health_clinic_id: pup.health_clinic_id
    )

    user_session.update!(fulfilled_by_id: researcher.id, started: true)
    user_intervention.in_progress! if user_intervention.ready_to_start?

    create_answers(user_session, variable_answers)

    if all_answerable_questions_answered?(user_session)
      user_session.finish
      :completed
    else
      :partial
    end
  end

  def create_answers(user_session, variable_answers)
    variable_answers.each do |key, raw_value|
      _session_var, question_var = key.split('.', 2).map { |part| part.to_s.strip }
      question = question_lookup.fetch(question_var)
      answer_class = QUESTION_TO_ANSWER.fetch(question.type)

      answer = answer_class.find_or_initialize_by(question_id: question.id, user_session_id: user_session.id)
      answer.assign_attributes(
        body: { 'data' => [{ 'var' => question_var, 'value' => raw_value.to_s.strip }] },
        draft: false,
        alternative_branch: false
      )
      answer.save!
    end
  end

  def all_answerable_questions_answered?(user_session)
    answered_question_ids = Answer.where(user_session_id: user_session.id).pluck(:question_id)
    answerable_question_ids = question_lookup.values.map(&:id).uniq
    (answerable_question_ids - answered_question_ids).empty?
  end
end
