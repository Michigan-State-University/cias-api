# frozen_string_literal: true

class DuplicateMailer < ApplicationMailer
  def confirmation(user, old_session, new_intervention)
    @user = user
    @old_session = old_session
    @new_intervention = new_intervention

    mail(to: @user.email, subject: I18n.t('clone_mailer.session.subject', session_name: @old_session.name))
  end
end
