# frozen_string_literal: true

class V1::Organizations::Invitations::Confirm
  prepend Database::Transactional

  def self.call(organization_invitation)
    new(organization_invitation).call
  end

  def initialize(organization_invitation)
    @organization = organization_invitation.organization
    @user = organization_invitation.user
    @organization_invitation = organization_invitation
  end

  def call
    user.activate! if user.role?('organization_admin')

    set_pending_e_intervention_admin
    organization_invitation.update!(
      accepted_at: Time.current,
      invitation_token: nil
    )
  end

  private

  attr_reader :organization, :user, :organization_invitation

  def set_pending_e_intervention_admin
    return unless user.role?('researcher') && !user.role?('e_intervention_admin')

    user.update!(roles: user.roles << 'e_intervention_admin') if can_be_e_intervention_admin?
  end

  def can_be_e_intervention_admin?
    organization_admins_ids = organization.e_intervention_admin_organizations.map(&:user).map(&:id)
    e_intervention_admin_id = EInterventionAdminOrganization.find_by(user_id: user.id, organization_id: organization.id)&.user&.id
    return false if organization_admins_ids.empty? || e_intervention_admin_id.nil?

    organization_admins_ids.include? e_intervention_admin_id
  end
end
