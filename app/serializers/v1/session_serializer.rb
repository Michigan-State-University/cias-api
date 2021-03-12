# frozen_string_literal: true

class V1::SessionSerializer < V1Serializer
  attributes :settings, :position, :name, :schedule, :schedule_payload, :schedule_at,
             :formula, :body, :intervention_id, :report_templates_count, :sms_plans_count

  attribute :generated_report_count do |object|
    GeneratedReport.joins(:user_session).where(user_sessions: { session_id: object.id }).size
  end
end
