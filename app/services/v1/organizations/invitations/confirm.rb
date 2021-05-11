# frozen_string_literal: true

class V1::Organizations::Invitations::Confirm
  def self.call(organization_invitation)
    new(organization_invitation).call
  end

  def initialize(organization_invitation)
    @organization = organization_invitation.organization
    @user = organization_invitation.user
    @organization_invitation = organization_invitation
  end

  def call
    ActiveRecord::Base.transaction do
      user.update!(organizable: organization)
      if user.role?('organization_admin')
        user.activate!
        organization.organization_admins << user
      else
        organization.e_intervention_admins << user
      end

      organization_invitation.update!(
        accepted_at: Time.current,
        invitation_token: nil
      )
    end
  end

  private

  attr_reader :organization, :user, :organization_invitation
end
