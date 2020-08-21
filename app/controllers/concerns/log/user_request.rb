# frozen_string_literal: true

module Log::UserRequest
  extend ActiveSupport::Concern

  included do
    after_action :leave_footprint
  end

  def leave_footprint
    LogJob::UserRequest.perform_later(request_scope) if current_v1_user
  end

  private

  def request_scope
    erase_from_params
    {
      user_id: current_v1_user.id,
      controller: params[:controller].to_s,
      action: params[:action].to_s,
      query_string: request.query_parameters,
      params: params.except(:controller, :action).to_unsafe_h,
      user_agent: request.headers['HTTP_USER_AGENT'],
      remote_ip: request.remote_ip
    }
  end

  def erase_from_params
    params[:user]&.delete(:password)
    params[:user]&.delete(:password_confirmation)
    params[:image]&.delete(:file)
  end
end
