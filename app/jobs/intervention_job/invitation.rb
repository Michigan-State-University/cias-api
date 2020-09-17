# frozen_string_literal: true

class InterventionJob::Invitation < InterventionJob
  def perform(intervention_id, emails)
    intervention = Intervention.find(intervention_id)
    emails.each do |email|
      InterventionMailer.inform_to_an_email(
        intervention,
        email
      ).deliver_now
    end
  end
end
