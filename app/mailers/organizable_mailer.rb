# frozen_string_literal: true

class OrganizableMailer < ApplicationMailer
  def invite_user(invitation_token:, email:, organizable:, organizable_type:)
    @invitation_token = invitation_token
    @organizable = organizable
    @organizable_type = organizable_type
    @invitation_link = invitation_link

    mail(to: email,
         subject: I18n.t('organizable_mailer.invite_user.subject', organizable_type: @organizable_type))
  end

  def invitation_link
    case @organizable_type
    when 'Organization'
      v1_organization_invitations_confirm_url(invitation_token: @invitation_token)
    when 'Health System'
      v1_health_system_invitations_confirm_url(invitation_token: @invitation_token)
    when 'Health Clinic'
      v1_health_clinic_invitations_confirm_url(invitation_token: @invitation_token)
    end
  end
end
