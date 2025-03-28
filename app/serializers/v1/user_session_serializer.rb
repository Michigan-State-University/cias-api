# frozen_string_literal: true

class V1::UserSessionSerializer < V1Serializer
  attributes :finished_at, :last_answer_at, :type, :user_intervention_id, :filled_out_count, :started

  attribute :logo_url do |object|
    intervention_id = Session.find(object.session_id).intervention_id
    url_for(Intervention.find(intervention_id).logo) if Intervention.find(intervention_id).logo.attached?
  end

  attribute :image_alt do |object|
    intervention_id = Session.find(object.session_id).intervention_id
    intervention = Intervention.find(intervention_id)
    intervention.logo_blob.description if intervention.logo_blob.present?
  end

  attribute :language_name do |object|
    object.session.google_language.language_name
  end

  attribute :language_code do |object|
    object.session.google_language.language_code
  end

  attribute :session_id do |object|
    object.session.id
  end

  attribute :session_name do |object|
    object.session.name
  end

  attribute :scheduled_at do |object|
    object.scheduled_at&.iso8601
  end

  attribute :intervention_type do |object|
    object.session.intervention.type
  end

  attribute :quick_exit_enabled do |object|
    object.session.intervention.quick_exit
  end

  attribute :shared_to do |object|
    object.session.intervention.shared_to
  end

  attribute :live_chat_enabled do |object|
    object.session.intervention.live_chat_enabled
  end
end
