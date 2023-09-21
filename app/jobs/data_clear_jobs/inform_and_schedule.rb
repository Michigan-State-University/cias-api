# frozen_string_literal: true

class DataClearJobs::InformAndSchedule < ApplicationJob
  def perform(intervention_id, number_of_days_to_remove)
    @number_of_days_to_remove = number_of_days_to_remove
    @intervention = Intervention.find(intervention_id)

    DataClearJobs::ClearUserData.set(wait: number_of_days_to_remove.days).perform_later(intervention_id)

    send_emails_to_third_party_users!(@intervention)
    send_emails_to_participants!(@intervention)
  end

  private

  def send_emails_to_third_party_users!(intervention)
    User.joins(generated_reports_third_party_users: :generated_report)
        .where(generated_report: { report_template_id: intervention.sessions.joins(:report_templates)
                                                                   .select('report_templates.id') }).distinct.find_each do |third_party|
      send_email!(third_party) if third_party.confirmed?
    end
  end

  def send_emails_to_participants!(intervention)
    intervention.user_interventions.find_each do |user_intervention|
      user = user_intervention.user
      if user.role?('guest')
        User.where(id: user_intervention.user_sessions.joins(:generated_reports).select('generated_reports.participant_id')).find_each do |created_user|
          next unless created_user.confirmed?

          send_email!(created_user)
        end
      else
        send_email!(user)
      end
    end
  end

  def send_immediately?
    @number_of_days_to_remove.zero?
  end

  def send_email!(user)
    return InterventionMailer::ClearDataMailer.data_deleted(user, @intervention).deliver_now if send_immediately?

    InterventionMailer::ClearDataMailer.inform(user, @intervention, @number_of_days_to_remove).deliver_now
  end
end
