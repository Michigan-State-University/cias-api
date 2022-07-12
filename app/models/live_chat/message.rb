# frozen_string_literal: true

class LiveChat::Message < ApplicationRecord
  self.table_name = 'live_chat_messages'

  belongs_to :conversation, class_name: 'LiveChat::Conversation'
  belongs_to :live_chat_interlocutor, class_name: 'LiveChat::Interlocutor'
  delegate :user, to: :live_chat_interlocutor

  validates :content, length: { maximum: 500, too_long: I18n.t('activerecord.errors.models.live_chat.message.attributes.content.too_long', limit: 500) }
  validate :conversation_archived?, on: :create

  default_scope { order(created_at: :asc) }

  private

  def conversation_archived?
    errors.add(:base, I18n.t('activerecord.errors.models.live_chat.message.sent_in_archived_conversation')) if conversation&.archived
  end
end
