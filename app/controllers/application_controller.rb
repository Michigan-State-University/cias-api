# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :require_custom_header, if: :e2e_origin?
  before_action :user_params, if: :devise_controller?
  include Log

  rate_limit to: ENV.fetch('RATE_LIMIT', 100).to_i, within: 1.minute

  protected

  def user_params
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name time_zone terms])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[email])
    devise_parameter_sanitizer.permit(:accept_invitation, keys: %i[first_name last_name phone])
  end

  def require_custom_header
    return if ActiveSupport::SecurityUtils.secure_compare(
      request.headers['End-To-End-Secure-Token'],
      ENV.fetch('CI_E2E_TOKEN', '')
    )

    render json: { error: 'Forbidden' }, status: :forbidden
  end

  def e2e_origin?
    request.headers['Origin'] == ENV.fetch('CI_E2E_WEB_URL', '')
  end
end
