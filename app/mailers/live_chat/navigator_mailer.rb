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
end