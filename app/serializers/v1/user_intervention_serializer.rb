# frozen_string_literal: true

class V1::UserInterventionSerializer < V1Serializer
  attributes :completed_sessions, :status, :last_answer_date

  attribute :sessions_in_intervention do |object|
    object.sessions.size
  end

  attribute :sessions, if: proc { |_record, params| !(params[:exclude].present? && params[:exclude].include?(:sessions)) } do |object|
    V1::SessionSerializer.new(object.intervention.sessions)
  end

  attribute :user_sessions, if: proc { |_record, params| !(params[:exclude].present? && params[:exclude].include?(:sessions)) } do |object|
    V1::UserSessionSerializer.new(object.user_sessions)
  end

  attribute :blocked do |object|
    object.intervention.shared_to_invited? && object.intervention.intervention_accesses.pluck(:email).exclude?(object.user.email)
  end

  attribute :intervention do |object|
    {
      name: object.intervention.name,
      type: object.intervention.type,
      additional_text: object.intervention.additional_text,
      logo_url: object.intervention.logo.attached? ? url_for(object.intervention.logo) : nil,
      image_alt: object.intervention.logo_blob.present? ? object.intervention.logo_blob.description : nil,
      id: object.intervention.id,
      files: object.intervention.files.attached? ? file_data(object) : []
    }
  end

  def self.file_data(object)
    object.intervention.files.map do |file|
      {
        id: file.id,
        name: file.blob.filename,
        url: ENV['APP_HOSTNAME'] + Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true)
      }
    end
  end
end