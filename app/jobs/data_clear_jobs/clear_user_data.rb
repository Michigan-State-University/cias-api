# frozen_string_literal: true

class DataClearJobs::ClearUserData < ApplicationJob
  def perform(intervention_id)
    intervention = Intervention.find(intervention_id)
    ActiveRecord::Base.transaction do
      V1::SmsPlans::CancelScheduledSmses.call(intervention_id)

      intervention.reports.destroy_all # remove all csv files
      intervention.user_interventions.destroy_all
      intervention.conversations.destroy_all
      intervention.conversations_transcript.destroy
      delete_quest_users_without_any_intervention!

      intervention.sensitive_data_removed!
      create_notification!(intervention)
    end
  end

  private

  def delete_quest_users_without_any_intervention!
    User.left_joins(:user_interventions).where(roles: ['guest'], user_interventions: { id: nil }).destroy_all
  end

  def create_notification!(intervention)
    Notification.create!(user: intervention.user, notifiable: intervention, event: :sensitive_data_removed,
                         data: { intervention_name: intervention.name, intervention_id: intervention.id })
  end
end
