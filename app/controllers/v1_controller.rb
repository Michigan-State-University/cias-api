# frozen_string_literal: true

class V1Controller < ApplicationController
  include DeviseTokenAuth::Concerns::SetUserByToken
  include ExceptionHandler
  include Log
  before_action :authenticate_user!, unless: :devise_controller?

  def current_ability
    @current_ability ||= current_user.ability
  end

  private

  def serialized_response(collection)
    "V1::#{controller_name.classify}Serializer".safe_constantize.
      new(collection).serialized_json
  end
end
