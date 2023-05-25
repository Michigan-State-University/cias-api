# frozen_string_literal: true

class CollaboratorChannel < ApplicationCable::Channel
  def subscribed
    stream_from current_channel_id
    ensure_confirmation_sent
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    stop_all_streams
  end

  private

  def collaborator_channel_id
    "collaborating_on_#{params[:id]}_channel"
  end
end
