# frozen_string_literal: true

class V1::Auth::SessionsController < DeviseTokenAuth::SessionsController
  before_action :verify_account_integrity, only: :create

  include ExceptionHandler
  include Resource
  prepend Auth::Default
  include Log
  include ActionController::Cookies

  def verify_account_integrity
    @resource = User.find_by(email: params[:email])

    return unless @resource&.valid_password?(resource_params[:password])

    if @resource&.missing_require_fields?
      raise ComplexException.new(I18n.t('activerecord.errors.models.user.terms_not_accepted'),
                                 { reason: 'TERMS_NOT_ACCEPTED', require_fields: @resource.slice(:first_name, :last_name, :terms, :roles) }, :forbidden)
    end

    return unless V1::Users::Verifications::Create.call(@resource, cookies['verification_code'] || params[:verification_code])

    raise ComplexException.new(I18n.t('activerecord.errors.models.user.2fa_code_needed'), { reason: '2FA_NEEDED' }, :forbidden)
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
