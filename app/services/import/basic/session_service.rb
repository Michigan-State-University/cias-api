# frozen_string_literal: true

class Import::Basic::SessionService
  include ImportOperations

  def self.call(intervention_id, session_hash)
    new(
      intervention_id,
      session_hash.except(:version)
    ).call
  end

  def initialize(intervention_id, session_hash)
    @session_hash = session_hash
    @intervention_id = intervention_id
  end

  attr_reader :session_hash, :intervention_id

  def call
    question_groups = session_hash.delete(:question_groups)
    report_templates = session_hash.delete(:report_templates)
    sms_plans = session_hash.delete(:sms_plans)
    session_hash.delete(:relations_data)
    session = Session.create!(session_hash.merge({ intervention_id: intervention_id, google_tts_voice_id: voice_id }))
    session.question_groups.destroy_all
    question_groups&.each do |question_group_hash|
      get_import_service_class(question_group_hash, QuestionGroup).call(session.id, question_group_hash)
    end

    report_template_id_map = {}
    report_templates&.each do |report_templates_hash|
      source_id = report_templates_hash[:id]
      new_template = get_import_service_class(report_templates_hash, ReportTemplate).call(session.id, report_templates_hash)
      report_template_id_map[source_id] = new_template.id if source_id.present?
    end
    reassign_report_templates_to_third_party_screens(session, report_template_id_map)

    sms_plans&.each do |sms_plan_hash|
      get_import_service_class(sms_plan_hash, SmsPlan).call(session.id, sms_plan_hash)
    end
    session
  end

  private

  def reassign_report_templates_to_third_party_screens(session, id_map)
    return if id_map.empty?

    Question::ThirdParty
      .includes(:question_group)
      .where(question_groups: { session_id: session.id })
      .find_each do |question|
        question.body_data.each do |row|
          row['report_template_ids'] = Array(row['report_template_ids']).filter_map { |old_id| id_map[old_id] }
        end
        question.save!
      end
  end

  def voice_id
    @voice_id ||= GoogleTtsVoice.find_by(
      voice_label: session_hash.delete(:voice_label),
      voice_type: session_hash.delete(:voice_type),
      language_code: session_hash.delete(:language_code)
    )&.id
  end
end
