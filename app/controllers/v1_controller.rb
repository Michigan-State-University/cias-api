# frozen_string_literal: true

class V1Controller < ApplicationController
  include DeviseTokenAuth::Concerns::SetUserByToken
  include ExceptionHandler
  include Pagination
  include Resource

  before_action :authenticate_user!
  before_action :set_paper_trail_whodunnit

  def current_v1_user
    @current_v1_user ||= super
  end

  def user_for_paper_trail
    current_v1_user.id if signed_in?
  end

  def create_guest_user
    V1::Users::CreateGuest.call
  end

  def create_preview_session_user(session_id)
    User.new.tap do |u|
      u.preview_session_id = session_id
      u.roles = %w[preview_session]
      u.email = "#{Time.current.to_i}_#{SecureRandom.hex(10)}@preview.session"
      u.skip_confirmation!
      u.save(validate: false)
    end
  end

  protected

  def with_locale
    I18n.with_locale(locale) { yield }
  end

  private

  def locale
    raise NotImplementedError
  end

  def authenticate_user!
    head :unauthorized unless signed_in?
  end

  def signed_in?
    current_v1_user.present?
  end

  def current_ability
    @current_ability ||= current_v1_user.ability
  end

  def invalidate_cache(obj)
    Rails.cache.delete(obj.cache_key)
  end

  def render_json(**params)
    path = params[:path].presence || controller_path
    action = params[:action].presence || action_name
    serializer = "#{path}/#{action}".classify.constantize

    render json: serializer.new(params.except(:path, :action, :status)).render, status: params[:status]
  end

  def redirect_to_web_app(**message)
    message.transform_values! { |v| Base64.encode64(v) }

    redirect_to "#{ENV['WEB_URL']}?#{message.to_query}"
  end
end
