# frozen_string_literal: true

class V1::Export::SessionSerializer < ActiveModel::Serializer
  include ExportHelper

  attributes :settings, :position, :name, :schedule, :schedule_payload, :schedule_at, :formulas, :variable,
             :days_after_date_variable_name, :type, :original_text, :estimated_time, :multiple_fill, :body, :current_narrator,
             :welcome_message, :default_response, :google_language_id

  has_many :question_groups, serializer: V1::Export::QuestionGroupSerializer
  has_many :sms_plans, serializer: V1::Export::SmsPlanSerializer
  has_many :report_templates, serializer: V1::Export::ReportTemplateSerializer

  attribute :voice_type do
    object.google_tts_voice&.voice_type
  end

  attribute :voice_label do
    object.google_tts_voice&.voice_label
  end

  attribute :language_code do
    object.google_tts_voice&.language_code
  end

  attribute :relations_data do
    branching_data(object)
  end

  attribute :version do
    Session::CURRENT_VERSION
  end

  private

  def branching_data(session)
    branch_target_locations = []
    targets = session.formulas.flat_map { |formula| formula['patterns'].flat_map { |pattern| pattern['target'] } }
    targets.each do |target|
      next if target['id'].blank?

      target_session = Session.find(target['id'])
      next if target_session.nil?

      location = object_location(target_session)
      branch_target_locations << location unless branch_target_locations.include?(location)
    end
    branch_target_locations
  end
end
