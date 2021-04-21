# frozen_string_literal: true

class V1::Auth::SessionsController < DeviseTokenAuth::SessionsController
  include Resource
  prepend Auth::Default
  include Log

  private

  # To handle deactivated account scenario I have to override either this or `create` method
  def render_create_error_not_confirmed
    if @resource.active?
      render_error(401, I18n.t('devise_token_auth.sessions.not_confirmed', email: @resource.email))
    else
      render_error(401, I18n.t('devise_token_auth.sessions.deactivated'))
    end
  end
end
