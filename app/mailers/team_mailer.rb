# frozen_string_literal: true

class TeamMailer < ApplicationMailer
  def invite_user(invitation_token:, email:, team:)
    @invitation_token = invitation_token
    @team             = team

    mail(to: email, subject: I18n.t('team_mailer.invite_user.subject', team_name: team.name))
  end
end
