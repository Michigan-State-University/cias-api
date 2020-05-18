# frozen_string_literal: true

class ApplicationController < ActionController::API
  include DeviseTokenAuth::Concerns::SetUserByToken
  include ExceptionHandler
  include AdjustedLogger
  before_action :authenticate_user!, unless: :devise_controller?, except: :status

  def current_ability
    @current_ability ||= current_user.ability
  end

  def status
    render json: { message: 'all systems operational' }
  end
end
