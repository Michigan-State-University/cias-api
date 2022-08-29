# frozen_string_literal: true

class V1::NotificationSerializer < V1Serializer
  attributes :notifiable_type, :notifiable_id, :is_read, :created_at, :data
end
