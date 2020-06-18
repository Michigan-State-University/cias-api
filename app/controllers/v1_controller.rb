# frozen_string_literal: true

class V1Controller < ApplicationController
  include DeviseTokenAuth::Concerns::SetUserByToken
  include ExceptionHandler
  include Log
  before_action :authenticate_user!, unless: :devise_controller?

  private

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
