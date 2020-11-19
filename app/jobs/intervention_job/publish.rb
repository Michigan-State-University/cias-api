# frozen_string_literal: true

class InterventionJob::Publish < InterventionJob
  def perform(id)
    session = Intervention.find(id)
    all_sessions = session.problem.interventions.order(:position).includes([:intervention_invitations])
    current_index = all_sessions.find_index session
    operational_sessions = all_sessions.slice(0..current_index)
    emails = operational_sessions.map { |s| s.intervention_invitations.map(&:email) }.flatten.uniq
    inform_participants(emails, session) if emails.present?
  end

  private

  def inform_participants(emails, session)
    emails.each do |email|
      InterventionMailer.inform_to_an_email(
        session,
        email
      ).deliver_now
    end
  end
end
