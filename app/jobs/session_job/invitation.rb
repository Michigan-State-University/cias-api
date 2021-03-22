# frozen_string_literal: true

class SessionJob::Invitation < SessionJob
  def perform(session_id, emails)
    users = User.where(email: emails)
    session = Session.find(session_id)
    users.each do |user|
      next unless user.email_notification

      SessionMailer.inform_to_an_email(
        session,
        user.email
      ).deliver_now
    end
  end
end
