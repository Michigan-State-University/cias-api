# frozen_string_literal: true

class InterventionMailer::ClearDataMailer < ApplicationMailer
  def inform(user, intervention, number_of_days)
    @user = user
    @intervention = intervention
    @number_of_days = number_of_days

    mail(to: user.email, subject: I18n.t('mailer.clear_data.subject'))
  end

  def data_deleted(user, intervention)
    @user = user
    @intervention = intervention

    mail(to: user.email, subject: I18n.t('mailer.data_removed.subject'))
  end
end
