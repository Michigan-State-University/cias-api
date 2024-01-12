# frozen_string_literal: true

class InterventionMailer::PredefinedParticipantsMailer < ApplicationMailer
  def invitation_user(user, link)
    @link = link

    mail(to: user.email, subject: I18n.t('mailer.collaborators.subject'))
  end
end
