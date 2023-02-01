# frozen_string_literal: true

class LiveChat::NavigatorMailer < ApplicationMailer
  def navigator_intervention_invitation(email, intervention)
    @email = email
    @intervention = intervention

    mail(to: email, subject: I18n.t('navigator_mailer.invitation.subject'))
  end

  def navigator_from_team_invitation(email, intervention)
    @email = email
    @intervention = intervention

    mail(to: email, subject: I18n.t('navigator_mailer.from_team.invitation.subject'))
  end

  def navigator_call_out_mail(email, intervention)
    @email = email
    @intervention = intervention

    mail(to: email, subject: I18n.t('navigator_mailer.call_out.subject'))
  end

  def participant_handled_mail(email, intervention)
    @email = email
    @intervention = intervention

    mail(to: email, subject: I18n.t('navigator_mailer.participant_handled.subject'))
  end
end
