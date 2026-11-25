# frozen_string_literal: true

class V1::Auth::PasswordsController < DeviseTokenAuth::PasswordsController
  include Resource
  include Log
  include Auth::Default
  include Auth::WebAppRedirectUrlCheck

  # Runs after DTA's validate_redirect_url_param, which sets @redirect_url
  # rubocop:disable Rails/LexicallyScopedActionFilter
  before_action :validate_web_app_redirect_url, only: %i[create edit]
  # rubocop:enable Rails/LexicallyScopedActionFilter

  protected

  def render_create_success
    head :created
  end

  def render_not_found_error
    head :created
  end

  private

  def redirect_url_to_check
    @redirect_url
  end
end
