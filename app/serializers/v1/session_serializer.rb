# frozen_string_literal: true

class V1::SessionSerializer < V1Serializer
  attributes :settings, :position, :name, :schedule, :schedule_payload, :schedule_at,
             :formulas, :body, :intervention_id, :report_templates_count, :sms_plans_count, :variable,
             :days_after_date_variable_name

  attribute :generated_report_count do |object|
    GeneratedReport.joins(:user_session).where(user_sessions: { session_id: object.id }).size
  end

  attribute :logo_url do |object|
    url_for(Intervention.find(object.intervention_id).logo) if Intervention.find(object.intervention_id).logo.attached?
  end

  attribute :google_tts_voice do |object|
    GoogleTtsVoice.find(object.google_tts_voice_id)
  end

  attribute :intervention_owner_id do |object|
    object.intervention.user.id
  end
end
