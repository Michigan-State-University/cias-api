# frozen_string_literal: true

class V1Controller < ApplicationController
  include DeviseTokenAuth::Concerns::SetUserByToken
  include ExceptionHandler
  include Log
  before_action :authenticate_user!, unless: :devise_controller?

  def current_user
    @current_user ||= begin
      if request.headers['guest'].eql?('create')
        create_guest_user
      else
        super
      end
    end
  end

  private

  def create_guest_user
    User.new.tap do |u|
      u.email = "#{Time.current.to_i}_#{SecureRandom.hex(10)}@guest.true"
      u.roles.push('guest')
      u.skip_confirmation!
      u.save(validate: false)
      response.headers.merge!(u.create_new_auth_token)
    end
  end

  def current_ability
    @current_ability ||= current_user.ability
  end

  def serialized_response(collection, from_model = controller_name.classify)
    "V1::#{from_model}Serializer".safe_constantize.
      new(collection).serialized_json
  end

  def invalidate_cache(obj)
    Rails.cache.delete(obj.cache_key)
  end
end
