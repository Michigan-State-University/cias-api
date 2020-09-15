# frozen_string_literal: true

class InvitationMailer::Participant < InvitationMailer
  def to_intervention(email, intervention)
    @email = email
    @intervention = intervention
    mail(to: @email, subject: I18n.t('invitation_mailer.participant.subject'))
  end
end
