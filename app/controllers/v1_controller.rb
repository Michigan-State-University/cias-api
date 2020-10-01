# frozen_string_literal: true

class V1Controller < ApplicationController
  include DeviseTokenAuth::Concerns::SetUserByToken
  include ExceptionHandler
  include Log
  include Pagination
  include Resource

  def current_v1_user
    @current_v1_user ||= super || create_guest_user
  end

  private

  def guest_user
    @guest_user ||= User.new.tap do |u|
      u.roles = %w[guest]
      u.skip_confirmation!
    end
  end

  def create_guest_user
    user = guest_user
    user.email = "#{Time.current.to_i}_#{SecureRandom.hex(10)}@guest.true"
    user.save(validate: false)
    response.headers.merge!(user.create_new_auth_token)
    user
  end

  def current_ability
    @current_ability ||= current_v1_user.ability
  end

  def invalidate_cache(obj)
    Rails.cache.delete(obj.cache_key)
  end

  def render_json(**params)
    path   = params[:path].presence || controller_path
    action = params[:action].presence || action_name
    serializer = [path, '/', action].join.classify.constantize

    render json: serializer.new(params.except(:path, :action, :status)).cached_render, status: params[:status]
  end
end
