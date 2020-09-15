# frozen_string_literal: true

class V1Controller < ApplicationController
  include DeviseTokenAuth::Concerns::SetUserByToken
  include ExceptionHandler
  include Log
  include Resource
  # before_action :authenticate_v1_user!, unless: :devise_controller?

  def current_v1_user
    @current_v1_user ||= super || create_guest_user
  end

  private

  def guest_user
    @guest_user ||= User.new.tap do |u|
      u.email = "#{Time.current.to_i}_#{SecureRandom.hex(10)}@guest.true"
      u.roles.push('guest')
      u.skip_confirmation!
    end
  end

  def create_guest_user
    user = guest_user
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
end
