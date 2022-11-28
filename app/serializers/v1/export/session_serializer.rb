# frozen_string_literal: true

class V1::Export::SessionSerializer < ActiveModel::Serializer
  attributes :settings, :position, :name, :schedule, :schedule_payload, :schedule_at, :formulas, :variable,
             :days_after_date_variable_name, :type, :original_text, :estimated_time, :body

  has_many :question_groups, serializer: V1::Export::QuestionGroupSerializer
  has_many :sms_plans, serializer: V1::Export::SmsPlanSerializer
  has_many :report_templates, serializer: V1::Export::ReportTemplateSerializer

  attribute :voice_type do
    object.google_tts_voice.voice_type
  end

  attribute :voice_label do
    object.google_tts_voice.voice_label
  end

  attribute :language_code do
    object.google_tts_voice.language_code
  end

  attribute :version do
    Session::CURRENT_VERSION
  end
end
