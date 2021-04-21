# frozen_string_literal: true

class OrganizationMailer < ApplicationMailer
  def invite_user(invitation_token:, email:, organization:)
    @invitation_token = invitation_token
    @organization = organization

    mail(to: email, subject: I18n.t('organization_mailer.invite_user.subject', organization_name: organization.name))
  end
end
