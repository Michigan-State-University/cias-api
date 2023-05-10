# frozen_string_literal: true

class V1::SessionSerializer < V1Serializer
  attributes :settings, :position, :name, :schedule, :schedule_payload, :schedule_at,
             :formulas, :intervention_id, :report_templates_count, :sms_plans_count, :variable,
             :days_after_date_variable_name, :google_tts_voice, :type, :cat_mh_language_id, :cat_mh_time_frame_id,
             :cat_mh_population_id, :created_at, :estimated_time, :current_narrator, :multiple_fill,
             :autofinish_enabled, :autofinish_delay

  has_many :cat_mh_test_types, serializer: V1::CatMh::TestTypeSerializer, if: proc { |record| record.type.eql?('Session::CatMh') }

  attribute :generated_report_count do |object|
    GeneratedReport.joins(:user_session).where(user_sessions: { session_id: object.id }).size
  end

  attribute :logo_url do |object|
    url_for(object.intervention.logo) if object.intervention.logo.attached?
  end

  attribute :intervention_owner_id do |object|
    object.intervention.user.id
  end
end
