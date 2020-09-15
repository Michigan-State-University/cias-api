# frozen_string_literal: true

class InvitationJob::Participant::Intervention < InvitationJob
  def perform(emails, intervention_id)
    intervention = Intervention.find(intervention_id)
    emails.each { |email| InvitationMailer::Participant.to_intervention(email, intervention).deliver_now }
  end
end
