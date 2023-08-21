# frozen_string_literal: true

class InterventionMailer::ClearDataMailer < ApplicationMailer
  def inform(user, intervention, number_of_days = 5)
    @user = user
    @intervention = intervention
    @number_of_days = number_of_days

    mail(to: user.email, subject: I18n.t('mailer.clear_data.subject'))
  end
end
