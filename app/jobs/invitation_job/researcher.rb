# frozen_string_literal: true

class InvitationJob::Researcher < InvitationJob
  def perform(emails)
    emails&.each do |email|
      User.invite!(email: email, roles: ['researcher'])
    end
  end
end
