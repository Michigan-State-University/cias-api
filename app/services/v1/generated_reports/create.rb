# frozen_string_literal: true

class V1::GeneratedReports::Create
  # Captures the variable name from `.:var:.` and `.:s1.var:.` placeholders.
  VARIABLE_PLACEHOLDER_PATTERN = /\.:([a-zA-Z0-9_.]+?):\./
  NOT_ANSWERED = 'Not answered'

  def self.call(report_template, user_session, dentaku_calculator)
    new(report_template, user_session, dentaku_calculator).call
  end

  def initialize(report_template, user_session, dentaku_service)
    @report_template = report_template
    @user_session = user_session
    @dentaku_service = dentaku_service
  end

  def call
    variants_to_generate =
      report_template.sections.map do |section|
        evaluate_section(section)
      end

    variants_to_generate.compact!

    insert_name_into_variants(variants_to_generate)
    variants_to_generate.reject! { |variant| only_unanswered_variables_used?(variant) }
    insert_variables_into_variants(variants_to_generate)

    return if variants_to_generate.blank?

    GeneratedReport.transaction do
      generated_report = GeneratedReport.create!(
        name: report_name,
        user_session_id: user_session.id,
        report_template_id: report_template.id,
        report_for: report_template.report_for
      )

      MetaOperations::FilesKeeper.new(
        stream: render_pdf_report(variants_to_generate),
        add_to: generated_report, filename: report_name,
        macro: :pdf_report, ext: :pdf, type: 'application/pdf'
      ).execute
    end
  end

  private

  attr_reader :report_template, :user_session, :dentaku_service, :user_intervention_service

  def evaluate_section(section)
    missing_variables = dentaku_service.dentaku_calculator.dependencies(section.formula)

    if missing_variables.any?
      nil
    else
      dentaku_service.evaluate(section.formula, section.variants)
    end
  rescue Dentaku::ParseError, Dentaku::TokenizerError, Dentaku::ArgumentError => e
    Rails.logger.error("Invalid formula in section #{section.id} of report template #{report_template.id}: #{e.message}")
    Rails.logger.error("Formula: #{section.formula}")
    nil
  end

  def render_pdf_report(variants_to_generate)
    V1::RenderPdfReport.call(
      report_template: report_template,
      variants_to_generate: variants_to_generate
    )
  end

  def name_variable
    @name_variable ||= Answer::Name.find_by(
      user_session_id: user_session.id
    )&.body_data&.first&.dig('value').presence&.dig('name')
  end

  def insert_name_into_variants(variants_to_generate)
    variants_to_generate.each { |variant| variant.content.gsub!('.:name:.', name_variable.presence || 'Participant') }
  end

  def insert_variable_into_variants(variable_name, variable_value, variants_to_generate)
    variants_to_generate.each { |variant| variant.content.gsub!(".:#{variable_name}:.", variable_value.to_s) }
  end

  def insert_variables_into_variants(variants_to_generate)
    answered_variables.each do |variable, value|
      insert_variable_into_variants(variable, value, variants_to_generate)
    end

    variants_to_generate.each { |variant| mark_unanswered_variables(variant) }
  end

  def mark_unanswered_variables(variant)
    variant.content.gsub!(VARIABLE_PLACEHOLDER_PATTERN) do |placeholder|
      intervention_variables.include?(Regexp.last_match(1)) ? NOT_ANSWERED : placeholder
    end
  end

  def only_unanswered_variables_used?(variant)
    used_variables = variant.content.scan(VARIABLE_PLACEHOLDER_PATTERN).flatten
    used_variables.any? { |variable| intervention_variables.include?(variable) } &&
      used_variables.none? { |variable| answered_variables.key?(variable) }
  end

  def answered_variables
    @answered_variables ||= user_intervention_answer_vars.compact_blank
  end

  def intervention_variables
    @intervention_variables ||= user_session.session.intervention.sessions.each_with_object(Set.new) do |session, variables|
      prefix = session.id == user_session.session_id ? '' : "#{session.variable}."
      session.fetch_variables.each do |group|
        group[:variables].each { |variable| variables << "#{prefix}#{variable.tr('/', '')}" }
      end
    end
  end

  def user_intervention_service
    @user_intervention_service ||= V1::UserInterventionService.new(user_session.user_intervention_id, user_session.id)
  end

  def user_intervention_answer_vars
    user_intervention_service.var_values
  end

  def report_name
    @report_name ||= "Report #{I18n.l(Time.current, format: :report_file)}"
  end
end
