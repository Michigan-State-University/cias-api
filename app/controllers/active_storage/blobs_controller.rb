# frozen_string_literal: true

class ActiveStorage::BlobsController < ActiveStorage::BaseController
  AUTHENTICABLE_ATTACHMENTS = %w[pdf_report reports].freeze

  include DeviseTokenAuth::Concerns::SetUserByToken
  include ActiveStorage::SetBlob
  include ExceptionHandler
  include Log

  def show
    return head :no_content unless user_authenticated?

    expires_in(ActiveStorage.service_urls_expire_in)
    redirect_to @blob.service_url(disposition: params[:disposition])
  end

  private

  def url_expires_in
    ActiveStorage::Blob.service.try(:url_expires_in) || 1.month
  end

  def user_authenticated?
    return true unless AUTHENTICABLE_ATTACHMENTS.include?(attachment.name)
    return false unless signed_in?

    authorize! :show, record
  end

  def record
    @record ||= attachment.record
  end

  def attachment
    @attachment ||= @blob.attachments.first
  end

  def signed_in?
    current_v1_user.present?
  end

  def current_ability
    @current_ability ||= current_v1_user.ability
  end

  def current_v1_user
    @current_v1_user ||= super
  end
end
