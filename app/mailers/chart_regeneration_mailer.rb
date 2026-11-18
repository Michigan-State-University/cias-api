# frozen_string_literal: true

class ChartRegenerationMailer < ApplicationMailer
  def regeneration_complete(user, chart)
    @user = user
    @chart = chart

    mail(to: @user.email, subject: I18n.t('chart_regeneration_mailer.complete.subject', chart_name: @chart.name))
  end
end
