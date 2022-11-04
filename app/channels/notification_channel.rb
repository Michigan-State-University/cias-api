# frozen_string_literal: true

class NotificationChannel < ApplicationCable::Channel
  include MessageHandler

  def subscribed
    stream_from user_channel_id
    unless current_user.navigator? && (current_user.researcher? || current_user.admin?)
      current_user.update!(online: true)
      update_navigator_availability
    end
    ensure_confirmation_sent
    return_unread_notifications
  end

  def unsubscribed
    stop_all_streams
    current_user.update!(online: false)
    update_navigator_availability
  end

  def on_read_notification(data)
    Notification.find(data['notificationId']).mark_as_readed
  end

  def on_navigator_availability_set(data)
    current_user.update!(online: data['online'])
    update_navigator_availability
  end

  private

  def return_unread_notifications
    response_data = V1::NotificationSerializer.new(Notification.unread_notifications(current_user.id))
    ActionCable.server.broadcast(user_channel_id, generic_message(response_data, 'unread_notifications_fetched'))
  end

  def update_navigator_availability
    return unless current_user.navigator?

    intervention_ids = active_channel_intervention_ids
    interventions = Intervention.includes(:intervention_navigators).where(id: intervention_ids, intervention_navigators: { user_id: current_user.id })
    interventions.find_each do |intervention|
      navigators = intervention.navigators.reload.where(online: true)
      status, topic = navigator_availability_status(navigators.size)
      ActionCable.server.broadcast("intervention_channel_#{intervention.id}", { interventionId: intervention.id, topic: topic, status: status })

      update_navigator_status_in_conversations(intervention)
    end
  end

  def update_navigator_status_in_conversations(intervention)
    conversation_topic, status = current_user.online ? ['current_navigator_available', 200] : ['current_navigator_unavailable', 404]
    intervention.conversations.user_conversations(current_user, false).find_each do |conversation|
      participant = conversation.users.limit_to_roles(%w[participant guest]).first
      data = {
        interventionId: intervention.id,
        conversationId: conversation.id
      }
      ActionCable.server.broadcast("user_conversation_channel_#{participant.id}", generic_message(data, conversation_topic, status))
    end
  end

  def redis_client
    @redis_client ||= ActionCable.server.pubsub.send(:redis_connection)
  end

  def active_channel_intervention_ids
    intervention_connections = redis_client.pubsub('channels', '*intervention_channel*')
    intervention_connections.filter_map { |connection_str| connection_str.match(/.*intervention_channel_(.*?)$/)&.captures&.first }
  end

  def navigator_availability_status(navigators_count)
    navigators_count.positive? ? [200, 'navigator_available'] : [404, 'navigator_unavailable']
  end

  def user_channel_id
    "notification_channel_#{current_user.id}"
  end

  def generic_message(payload, topic, status = 200)
    {
      data: payload,
      topic: topic,
      status: status
    }
  end
end
