# frozen_string_literal: true

class V1::Auth::ConfirmationsController < DeviseTokenAuth::ConfirmationsController
  include Resource
  include Log
  prepend Auth::Default

  protected

  # Due to changes in Rails 7, we need to add allow_other_host while redirecting
  def redirect_options
    @redirect_url&.start_with?(ENV.fetch('WEB_URL', nil)) ? { allow_other_host: true } : {}
  end
end
