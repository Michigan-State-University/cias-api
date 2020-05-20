# frozen_string_literal: true

class ApplicationController < ActionController::API
  def status
    render json: { message: 'all systems operational' }
  end
end
