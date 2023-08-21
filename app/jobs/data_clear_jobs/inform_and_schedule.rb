# frozen_string_literal: true

class DataClearJobs::InformAndSchedule < ApplicationJob
  def perform(intervention_id)
    intervention = Intervention.find(intervention_id)
    send_emails_to_third_party_users!(intervention)
    send_emails_to_participants!(intervention)

    DataClearJobs::ClearUserData.set(wait: 5.days).perform_later(intervention_id)
  end

  private

  def send_emails_to_third_party_users!(intervention)
    User.joins(generated_reports_third_party_users: :generated_report)
        .where(generated_report: { report_template_id: intervention.sessions.joins(:report_templates)
                                                                   .select('report_templates.id') }).distinct.find_each do |third_party|
      InterventionMailer::ClearDataMailer.inform(third_party, intervention).deliver_now if third_party.confirmed?
    end
  end

  def send_emails_to_participants!(intervention)
    intervention.user_interventions.find_each do |user_intervention|
      user = user_intervention.user
      if user.role?('guest')
        User.where(id: user_intervention.user_sessions.joins(:generated_reports).select('generated_reports.participant_id')).find_each do |created_user|
          next unless created_user.confirmed?

          InterventionMailer::ClearDataMailer.inform(created_user, intervention).deliver_now
        end
      else
        InterventionMailer::ClearDataMailer.inform(user, intervention).deliver_now
      end
    end
  end
end
