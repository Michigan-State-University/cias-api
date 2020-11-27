# frozen_string_literal: true

class Intervention::StatusKeeper
  def initialize(intervention_id)
    @intervention_id = intervention_id
  end

  def broadcast
    SessionJob::Broadcast.perform_later(intervention_id)
  end

  private

  attr_reader :intervention_id
end
