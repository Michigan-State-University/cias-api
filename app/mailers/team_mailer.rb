# frozen_string_literal: true

class TeamMailer < ApplicationMailer
  def invite_user(invitation_token:, email:, team:, roles:)
    @invitation_token = invitation_token
    @team             = team
    @roles = map_roles(roles)

    mail(to: email, subject: I18n.t('team_mailer.invite_user.subject', team_name: team.name))
  end

  private

  def map_roles(roles)
    if roles.include?('navigator') && roles.include?('researcher')
      'researcher and navigator'
    else
      roles.first
    end
  end
end
