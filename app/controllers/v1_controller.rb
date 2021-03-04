# frozen_string_literal: true

class V1Controller < ApplicationController
  include DeviseTokenAuth::Concerns::SetUserByToken
  include ExceptionHandler
  include Log
  include Pagination
  include Resource

  before_action :authenticate_user!

  def current_v1_user
    @current_v1_user ||= super
  end

  private

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
    path   = params[:path].presence || controller_path
    action = params[:action].presence || action_name
    serializer = "#{path}/#{action}".classify.constantize

    render json: serializer.new(params.except(:path, :action, :status)).cached_render, status: params[:status]
  end
end
