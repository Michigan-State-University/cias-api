# frozen_string_literal: true

class Interventions::PublishJob < ApplicationJob
  def perform(intervention_id)
    V1::Intervention::Publish.new(
      Intervention.find(intervention_id)
    ).execute
  end
end
