# frozen_string_literal: true

class DataClearJobs::ClearUserData < ApplicationJob
  def perform(intervention_id)
    intervention = Intervention.find(intervention_id)
    return if intervention.blank?

    intervention.reports.destroy_all # remove all csv files
    intervention.user_interventions.delete_all
    intervention.conversations.destroy_all
    intervention.conversations_transcript.destroy

    # TODO: check if they actually delete what they need to delete

    intervention.update!(data_cleared: true)
  end
end
