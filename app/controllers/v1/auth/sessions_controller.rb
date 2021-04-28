# frozen_string_literal: true

class V1::Auth::SessionsController < DeviseTokenAuth::SessionsController
  after_action :verify_login_code, only: :create

  include Resource
  prepend Auth::Default
  include Log

  def verify_login_code
    return unless @resource && @resource.valid_password?(resource_params[:password])

    head :forbidden if V1::Users::Verifications::Create.call(@resource, request.headers['Verification-Code'])
  end

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
