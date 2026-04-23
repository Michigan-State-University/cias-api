# frozen_string_literal: true

class V1::Intervention::PredefinedParticipants::VariableAnswersValidator
  SUPPORTED_QUESTION_TYPES = %w[Question::Single Question::Number Question::Date].freeze

  def self.call(intervention, participant_params_list)
    new(intervention, participant_params_list).call
  end

  def initialize(intervention, participant_params_list)
    @intervention = intervention
    @participant_params_list = participant_params_list
    @errors = []
  end

  def call
    return if @participant_params_list.none? { |p| p[:variable_answers].present? }

    raise_validation_error('ra_session_missing') if ra_session.blank?
    raise_validation_error('ra_session_has_no_answerable_questions') if question_lookup.empty?

    @participant_params_list.each_with_index do |params, idx|
      answers = params[:variable_answers]&.to_h
      next if answers.blank?

      answers.each { |key, raw_value| validate_entry(idx, key, raw_value) }
    end

    return if @errors.empty?

    raise ComplexException.new(
      I18n.t('predefined_participants.bulk_import.variable_answers_validation_error'),
      { errors: @errors },
      :unprocessable_entity
    )
  end

  private

  attr_reader :intervention

  def ra_session
    return @ra_session if defined?(@ra_session)

    @ra_session = intervention.sessions.find_by(type: 'Session::ResearchAssistant')
  end

  def question_lookup
    @question_lookup ||= ra_session.questions.each_with_object({}) do |question, lookup|
      question.question_variables.compact_blank.each { |var| lookup[var] = question }
    end
  end

  def validate_entry(index, key, raw_value)
    session_var, question_var = key.split('.', 2).map { |part| part.to_s.strip }

    return add_error(index, key, code: 'session_variable_mismatch') if session_var != ra_session.variable
    return add_error(index, key, code: 'unknown_question_variable') if question_var.blank? || !question_lookup.key?(question_var)

    question = question_lookup[question_var]
    return add_error(index, key, code: 'unsupported_question_type', question_type: question.type) unless SUPPORTED_QUESTION_TYPES.include?(question.type)

    value = raw_value.to_s.strip
    return add_error(index, key, code: 'value_blank') if value.blank?

    case question
    when Question::Single
      # Guard nil body['data'] (malformed question) → 422, not 500.
      valid_values = question.body['data']&.pluck('value') || []
      add_error(index, key, code: 'value_not_in_options', valid_values: valid_values) unless valid_values.include?(value)
    when Question::Number
      Float(value)
    when Question::Date
      Date.parse(value)
    end
  rescue ArgumentError, TypeError
    add_error(index, key, code: "value_not_a_#{question.type.demodulize.downcase}")
  end

  def add_error(index, key, code:, **context)
    @errors << { row: index, field: key, code: code, **context }
  end

  def raise_validation_error(code)
    raise ComplexException.new(
      I18n.t('predefined_participants.bulk_import.variable_answers_validation_error'),
      { errors: [{ code: code }] },
      :unprocessable_entity
    )
  end
end
