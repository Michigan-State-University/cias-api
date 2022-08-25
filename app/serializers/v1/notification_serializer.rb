# frozen_string_literal: true

class V1::NotificationSerializer < V1Serializer
  attributes :notifiable_type, :notifiable_id, :title, :description, :type, :is_read, :time_sent, :optional_link, :image_url
end
