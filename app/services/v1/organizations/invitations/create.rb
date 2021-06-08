# frozen_string_literal: true

class V1::Organizations::Invitations::Create
  def self.call(organization, user)
    new(organization, user).call
  end

  def initialize(organization, user)
    @organization = organization
    @user = user
  end

  def call
    return if invitation_already_exists?
    return unless user.confirmed?

    invitation = OrganizationInvitation.create!(
      user: user,
      organization: organization
    )

    OrganizableMailer.invite_user(
      invitation_token: invitation.invitation_token,
      email: user.email,
      organizable: organization,
      organizable_type: 'Organization'
    ).deliver_later
  end

  private

  attr_reader :organization, :user

  def invitation_already_exists?
    OrganizationInvitation.not_accepted.exists?(user_id: user.id, organization_id: organization.id)
  end
end
