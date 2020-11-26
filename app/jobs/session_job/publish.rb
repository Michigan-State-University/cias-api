# frozen_string_literal: true

class SessionJob::Publish < SessionJob
  def perform(id)
    session = Session.find(id)
    all_sessions = session.problem.sessions.order(:position).includes([:session_invitations])
    current_index = all_sessions.find_index session
    operational_sessions = all_sessions.slice(0..current_index)
    emails = operational_sessions.map { |s| s.session_invitations.map(&:email) }.flatten.uniq
    inform_participants(emails, session) if emails.present?
  end

  private

  def inform_participants(emails, session)
    emails.each do |email|
      SessionMailer.inform_to_an_email(
        session,
        email
      ).deliver_now
    end
  end
end
