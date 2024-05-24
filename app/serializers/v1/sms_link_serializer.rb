# frozen_string_literal: true

class V1::SmsLinkSerializer < V1Serializer
  attributes :session_id, :url, :variable_number, :link_type, :sms_plan_id
end
