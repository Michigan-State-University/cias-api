# frozen_string_literal: true

class V1::Auth::RegistrationsController < DeviseTokenAuth::RegistrationsController
  include Resource
  include Log
  include BlankParams
  prepend Auth::Default

  def create
    check_for_blank_params

    super
  end

  private

  def check_for_blank_params
    error_message_on_blank_param(params, %w[first_name last_name])
  end
end
