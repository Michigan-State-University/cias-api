# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :user_params, if: :devise_controller?

  protected

  def user_params
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[email])
  end
end
