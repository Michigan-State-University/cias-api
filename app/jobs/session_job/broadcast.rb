# frozen_string_literal: true

class SessionJob::Broadcast < SessionJob
  def perform(intervention_id)
    Intervention::StatusKeeper::Broadcast.new(
      Intervention.find(intervention_id)
    ).execute
  end
end
