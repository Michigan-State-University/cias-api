# frozen_string_literal: true

class V1::NotificationSerializer < V1Serializer
  attributes :notifiable_id, :title, :description, :is_read, :created_at, :optional_link, :image_url
end
