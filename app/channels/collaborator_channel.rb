# frozen_string_literal: true

class CollaboratorChannel < ApplicationCable::Channel
  def subscribed
    stream_from current_channel_id
    if intervention_id.present? # rubocop:disable Style/GuardClause
      if no_navigator_available?(intervention_id)
        ensure_confirmation_sent
        ActionCable.server.broadcast(current_channel_id,
                                     generic_message({}, 'navigator_unavailable', 404))
      end
      stream_from collaborator_channel_id
    end
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    stop_all_streams
  end

  private

  def collaborator_channel_id
    "collaborator_in_#{params[:id]}_channel"
  end
end
