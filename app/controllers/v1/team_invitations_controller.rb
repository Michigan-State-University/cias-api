# frozen_string_literal: true

class V1::TeamInvitationsController < ApplicationController
  def confirm
    V1::Teams::Invitations::Confirm.call(team_invitation)

    redirect_to_web_app(
      success: I18n.t('teams.invitations.accepted', team_name: team_invitation.team.name)
    )
  rescue ActiveRecord::RecordNotFound
    redirect_to_web_app(
      error: I18n.t('teams.invitations.not_found')
    )
  end

  private

  def team_invitation
    @team_invitation ||= TeamInvitation.not_accepted.
      find_by!(invitation_token: params.require(:invitation_token))
  end

  def redirect_to_web_app(**message)
    message.transform_values! { |v| Base64.encode64(v) }

    redirect_to "#{ENV['WEB_URL']}?#{message.to_query}"
  end
end
