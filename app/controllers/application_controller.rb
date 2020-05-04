# frozen_string_literal: true

class ApplicationController < ActionController::API
  include DeviseTokenAuth::Concerns::SetUserByToken

  def current_ability
    @current_ability ||= current_user.ability
  end
end
