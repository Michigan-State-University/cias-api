# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :user_params, if: :devise_controller?

  def status
    render json: { message: 'all systems operational' }
  end

  protected

  def user_params
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name username])
  end
end
