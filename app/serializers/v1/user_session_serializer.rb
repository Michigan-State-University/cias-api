# frozen_string_literal: true

class V1::UserSessionSerializer < V1Serializer
  attributes :finished_at, :last_answer_at

  attribute :logo_url do |object|
    intervention_id = Session.find(object.session_id).intervention_id
    url_for(Intervention.find(intervention_id).logo) if Intervention.find(intervention_id).logo.attached?
  end
end
