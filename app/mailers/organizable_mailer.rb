# frozen_string_literal: true

class OrganizableMailer < ApplicationMailer
  def invite_user(invitation_token:, email:, organizable:, organizable_type:)
    @invitation_token = invitation_token
    @organizable = organizable
    @organizable_type = organizable_type

    mail(to: email,
         subject: I18n.t('organizable_mailer.invite_user.subject', organizable_type: @organizable_type))
  end
end
