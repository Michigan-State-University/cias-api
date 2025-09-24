# frozen_string_literal: true

class V1::Notifications::TranscriptReady
  def self.call(object, user, object_name)
    new(object, user, object_name).call
  end

  def initialize(object, user, object_name)
    @object = object
    @user = user
    @object_name = object_name
  end

  def call
    Notification.create!(event: event, data: transcript_ready_body, notifiable: object, user: user)
  end

  attr_reader :object, :user, :object_name

  private

  def event
    object.is_a?(LiveChat::Conversation) ? :conversation_transcript_ready : :intervention_conversations_transcript_ready
  end

  def notification_object_body
    if object.is_a?(LiveChat::Conversation)
      {
        conversation_id: object.id,
        archived: object.archived?,
        transcript: object.transcript.attached? ? map_file_data(object.transcript) : nil
      }
    else
      {
        intervention_id: object.id,
        transcript: object.conversations_transcript.attached? ? map_file_data(object.conversations_transcript) : nil
      }
    end
  end

  def transcript_ready_body
    {
      intervention_name: object_name,
      **notification_object_body
    }
  end

  def map_file_data(file)
    {
      id: file.id,
      name: file.blob.filename,
      url: ENV.fetch('APP_HOSTNAME', nil) + Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true),
      created_at: file.blob.created_at.in_time_zone('UTC')
    }
  end
end
