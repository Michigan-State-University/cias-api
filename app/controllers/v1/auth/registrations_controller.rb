# frozen_string_literal: true

class V1::Auth::RegistrationsController < DeviseTokenAuth::RegistrationsController
  include Resource
  include Log
  include BlankParams
  prepend Auth::Default

  # rubocop:disable Rails/LexicallyScopedActionFilter
  before_action :check_for_blank_params, only: :create
  before_action :check_if_user_already_invited, only: :create
  # rubocop:enable Rails/LexicallyScopedActionFilter

  rescue_from ActiveRecord::ActiveRecordError do |exc|
    render json: { message: exc.message }, status: :unprocessable_entity
  end

  private

  def check_for_blank_params
    error_message_on_blank_param(params, %w[first_name last_name])
  end

  def check_if_user_already_invited
    user = resource_class.find_by(email: params[:email])

    raise ActiveRecord::ActiveRecordError, I18n.t('activerecord.errors.models.user.not_using_invitation_link') if user && pending_invitation?(user)
  end

  def pending_invitation?(user)
    !user.confirmed? && user.invitation_accepted_at.nil?
  end
end
