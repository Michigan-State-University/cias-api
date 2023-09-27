# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  around_action :with_locale, if: -> { params && params[:language].present? }

  default from: ENV['EMAIL_DEFAULT_FROM']
  layout 'mailer'

  protected

  def with_locale
    I18n.with_locale(params[:language]) { yield }
  end
end
