# frozen_string_literal: true

class V1::Auth::ConfirmationsController < DeviseTokenAuth::ConfirmationsController
  include Resource
  include Log
  include Auth::Default
  include Auth::WebAppRedirectUrlCheck

  # rubocop:disable Rails/LexicallyScopedActionFilter
  before_action :validate_web_app_redirect_url, only: %i[create show]
  # rubocop:enable Rails/LexicallyScopedActionFilter

  protected

  def render_create_success
    head :created
  end

  def render_not_found_error
    head :created
  end

  private

  def redirect_url
    params[:redirect_url].presence || "#{ENV.fetch('WEB_URL', nil)}/login"
  end

  def redirect_url_to_check
    redirect_url
  end
end
