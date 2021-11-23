# frozen_string_literal: true

module Log::UserRequest
  extend ActiveSupport::Concern

  included do
    after_action :leave_footprint
  end

  def leave_footprint
    LogJobs::UserRequest.perform_later(request_scope) unless ENV['LOG_OFF'] == 'true'
  end

  private

  def request_scope
    erase_from_params
    {
      user_id: current_v1_user&.id,
      controller: params[:controller].to_s,
      action: params[:action].to_s,
      query_string: request.query_parameters,
      params: params.except(:controller, :action).to_unsafe_h,
      user_agent: request.headers['HTTP_USER_AGENT'],
      remote_ip: request.remote_ip
    }
  end

  # rubocop:disable all
  def erase_from_params
    params[:user]&.delete(:password)
    params[:user]&.delete(:password_confirmation)
    params[:image]&.delete(:file)
    params[:avatar]&.delete(:file)
    params[:report_template]&.delete(:logo)
    params[:variant]&.delete(:image)
    params[:intervention]&.delete(:files)
    params[:logo]&.delete(:file)
    params.delete(:password)
    params.delete(:password_confirmation)
    params.delete(:registration)
    params.delete(:phone_number)
    params.delete(:email)
    params[:user]&.delete(:first_name)
    params[:user]&.delete(:last_name)
    params[:user][:phone_attributes]&.delete(:number) if params[:user].present?
    params.delete(:first_name)
    params.delete(:last_name)
    params[:answer]&.delete(:body)
    params[:user_session]&.delete(:emails)
    params[:session_invitation]&.delete(:emails)
    params[:invitation]&.delete(:email)
    params.delete(:current_password)
  end
  # rubocop:enable all
end
