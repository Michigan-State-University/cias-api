# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :notifiable, polymorphic: true
  belongs_to :user
  belongs_to :conversation, class_name: 'LiveChat::Conversation'
  validates :data, json: { schema: lambda {
    Rails.root.join("#{json_schema_path}/conversation/data.json").to_s
  }, message: lambda { |err|
    err
  } }

  private

  def json_schema_path
    @json_schema_path ||= 'db/schema/notification'
  end
end
