# frozen_string_literal: true

class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_from "notification_channel_#{current_user.id}"
    current_user.update!(online: true)
    update_navigator_availability
  end

  def unsubscribed
    stop_all_streams
    current_user.update!(online: false)
    update_navigator_availability
  end

  private

  def update_navigator_availability
    return unless current_user.navigator?

    intervention_ids = active_channel_intervention_ids
    interventions = Intervention.includes(:intervention_navigators).where(id: intervention_ids, intervention_navigators: { user_id: current_user.id })
    interventions.find_each do |intervention|
      navigators_count = intervention.navigators.reload.where(online: true).count
      status, topic = navigator_availability_status(navigators_count)
      ActionCable.server.broadcast("intervention_channel_#{intervention.id}", { interventionId: intervention.id, topic: topic, status: status })
    end
  end

  def redis_client
    @redis_client ||= ActionCable.server.pubsub.send(:redis_connection)
  end

  def active_channel_intervention_ids
    intervention_connections = redis_client.pubsub('channels', '*intervention_channel*')
    intervention_connections.filter_map { |connection_str| connection_str.match(/.*intervention_channel_(.*?)$/)&.captures&.first }
  end

  def navigator_availability_status(count)
    count.positive? ? [200, 'navigator_available'] : [404, 'navigator_unavailable']
  end
end
