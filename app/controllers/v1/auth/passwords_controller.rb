# frozen_string_literal: true

class V1::Auth::PasswordsController < DeviseTokenAuth::PasswordsController
  include Resource
  include Log
  prepend Auth::Default

  protected

  # Due to changes in Rails 7, we need to add allow_other_host while redirecting
  def redirect_options
    @redirect_url&.start_with?(ENV.fetch('WEB_URL', nil)) ? { allow_other_host: true } : {}
  end

  def render_create_success
    head :created
  end

  # We don't want to return information about that for a given email user exists or not.
  def render_not_found_error
    head :created
  end
end
