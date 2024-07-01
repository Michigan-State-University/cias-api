# frozen_string_literal: true

class V1::SmsLinkSerializer < V1Serializer
  attributes :session_id, :url, :link_type, :sms_plan_id, :variable
end
