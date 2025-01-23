# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :notifiable, polymorphic: true
  belongs_to :user

  after_create :send_notification

  enum event: { new_conversation: 0, auto_generated_conversation: 1, conversation_transcript_ready: 2, intervention_conversations_transcript_ready: 3,
                successfully_restored_intervention: 4, unsuccessful_intervention_import: 5, new_narrator_was_set: 6,
                new_collaborator_added: 7, start_editing_intervention: 8, stop_editing_intervention: 9, collaborator_removed: 10, sensitive_data_removed: 11 }

  validates :data, json: { schema: lambda {
    File.read(Rails.root.join("#{json_schema_path}/notification_data.json").to_s)
  }, message: lambda { |err|
    err
  } }

  scope :unread_notifications, ->(user_id) { where(user_id: user_id, is_read: false) }

  def mark_as_readed
    update!(is_read: true)
  end

  private

  def send_notification
    V1::NotifyService.call(self)
  end

  def json_schema_path
    @json_schema_path ||= 'db/schema/notification'
  end
end
