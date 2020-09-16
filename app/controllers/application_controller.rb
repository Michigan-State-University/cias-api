# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :error_beacon_context
  before_action :user_params, if: :devise_controller?

  protected

  def user_params
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name time_zone])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[email])
  end

  private

  def error_beacon_context
    Raven.user_context(id: session[:current_user_id])
    Raven.extra_context(params: params.to_unsafe_h, url: request.url)
  end
end
