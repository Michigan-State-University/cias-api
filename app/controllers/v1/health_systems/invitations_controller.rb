# frozen_string_literal: true

class V1::HealthSystems::InvitationsController < V1Controller
  before_action :authenticate_user!, except: [:confirm]

  def invite_health_system_admin
    authorize! :invite_health_system_admin, HealthSystem

    V1::HealthSystems::InviteHealthSystemAdmin.call(
      health_system,
      params.require(:email)
    )

    render status: :created
  end

  def confirm
    V1::HealthSystems::Invitations::Confirm.call(health_system_invitation)

    redirect_to_web_app(
      success: I18n.t('organizables.invitations.accepted', organizable_type: 'Health System',
                                                           organizable_name: health_system_invitation.health_system.name)
    )
  rescue ActiveRecord::RecordNotFound
    redirect_to_web_app(
      error: I18n.t('organizables.invitations.not_found', organizable_type: 'Health System')
    )
  end

  private

  def health_system_invitation
    @health_system_invitation ||= HealthSystemInvitation.not_accepted.
        find_by!(invitation_token: params.require(:invitation_token))
  end

  def health_system
    @health_system ||= HealthSystem.accessible_by(current_ability).find(params[:health_system_id])
  end
end
