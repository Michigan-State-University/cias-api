# frozen_string_literal: true

class InterventionMailer::CollaboratorsMailer < ApplicationMailer
  def invitation_user(user, intervention, new_user = false)
    @intervention = intervention
    @new_user = new_user

    if new_user
      user.send(:generate_invitation_token!) # same as in session mailer
      @invitation_token = user.raw_invitation_token
    end

    mail(to: user.email, subject: I18n.t('mailer.collaborators.subject'))
  end
end
