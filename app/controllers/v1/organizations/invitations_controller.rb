# frozen_string_literal: true

class V1::Organizations::InvitationsController < V1Controller
  def invite_intervention_admin
    authorize! :invite_e_intervention_admin, Organization

    V1::Organizations::InviteEInterventionAdmin.call(
      organization,
      params.require(:email)
    )

    render status: :created
  end

  def invite_organization_admin
    authorize! :invite_organization_admin, Organization

    V1::Organizations::InviteOrganizationAdmin.call(
      organization,
      params.require(:email)
    )

    render status: :created
  end

  def confirm
    V1::Organizations::Invitations::Confirm.call(organization_invitation)

    redirect_to_web_app(
      success: I18n.t('organizables.invitations.accepted', organizable_type: 'Organization',
                                                           organizable_name: organization_invitation.organization.name)
    )
  rescue ActiveRecord::RecordNotFound
    redirect_to_web_app(
      error: I18n.t('organizables.invitations.not_found', organizable_type: 'Organization')
    )
  end

  private

  def organization_invitation
    @organization_invitation ||= OrganizationInvitation.not_accepted.
        find_by!(invitation_token: params.require(:invitation_token))
  end

  def redirect_to_web_app(**message)
    message.transform_values! { |v| Base64.encode64(v) }

    redirect_to "#{ENV['WEB_URL']}?#{message.to_query}"
  end

  def organization
    @organization ||= Organization.accessible_by(current_ability).find(params[:organization_id])
  end
end
