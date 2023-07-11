# frozen_string_literal: true

module InvitationInterface
  def split_emails_exist(emails)
    existing_users = ::User.where(email: emails)
    existing_emails = existing_users.map(&:email)
    non_existing_emails = emails - existing_emails

    [existing_emails, non_existing_emails]
  end

  def invite_non_existing_users(emails, skip_invitation = false, roles = [:participant])
    emails.each do |email|
      User.invite!(email: email, roles: roles) { |user| user.skip_invitation = skip_invitation }
    end
  end
end
