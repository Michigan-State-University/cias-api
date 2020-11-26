# frozen_string_literal: true

class SessionJob::Invitation < SessionJob
  def perform(session_id, emails)
    session = Session.find(session_id)
    emails.each do |email|
      SessionMailer.inform_to_an_email(
        session,
        email
      ).deliver_now
    end
  end
end
