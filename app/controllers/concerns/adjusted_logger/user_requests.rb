# frozen_string_literal: true

module AdjustedLogger::UserRequests
  extend ActiveSupport::Concern

  included do
    before_action :leave_footprint
  end

  def leave_footprint
    AdjustedLoggerJob::UserRequests.perform_later(request_scope) if current_user
  end

  private

  def request_scope
    params[:user]&.delete(:password)
    params[:user]&.delete(:password_confirmation)
    {
      user_id: current_user.id,
      action: "#{params[:controller]}##{params[:action]}",
      query_string: request.query_parameters,
      params: params.to_unsafe_h,
      user_agent: request.headers['HTTP_USER_AGENT'],
      remote_ip: request.remote_ip
    }
  end
end
