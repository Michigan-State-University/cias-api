# frozen_string_literal: true

class V1::Auth::PasswordsController < DeviseTokenAuth::PasswordsController
  include Resource
  prepend Auth::Default

  protected

  def render_create_success
    head :created
  end

  # We don't want to return information about that for a given email user exists or not.
  def render_not_found_error
    head :created
  end
end
