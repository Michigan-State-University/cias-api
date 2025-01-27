# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  around_action :with_locale, if: -> { params && params[:locale].present? }

  default from: ENV.fetch('EMAIL_DEFAULT_FROM', nil)
  layout 'mailer'

  protected

  def with_locale
    I18n.with_locale(params[:locale]) { yield }
  end
end
