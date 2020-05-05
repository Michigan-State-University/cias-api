# frozen_string_literal: true

class ApplicationController < ActionController::API
  include DeviseTokenAuth::Concerns::SetUserByToken

  def current_ability
    @current_ability ||= current_user.ability
  end

  def status
    render json: 'all systems operational'
  end
end
