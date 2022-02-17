# frozen_string_literal: true

class CloneMailer < ApplicationMailer
  def result(user, resource, requested_at)
    @user = user
    @resource = resource
    @requested_at = requested_at
    mail(to: @user.email, subject: I18n.t('csv_mailer.answers.subject', intervention_name: @resource.name))
  end

  def cloned_intervention(user, intervention_name, cloned_intervention_id)
    @user = user
    @intervention_name = intervention_name
    @cloned_intervention_id = cloned_intervention_id

    mail(to: @user.email, subject: I18n.t('clone_mailer.intervention.subject', intervention_name: @intervention_name))
  end

  def cloned_session(user, session_name, cloned_session)
    @user = user
    @session_name = session_name
    @cloned_session = cloned_session

    mail(to: @user.email, subject: I18n.t('clone_mailer.session.subject', session_name: @session_name))
  end

  def error(user, error_msg)
    @user = user
    @error_msg = error_msg

    mail(to: @user.email, subject: I18n.t('clone_mailer.error.subject'))
  end
end
