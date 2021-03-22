# frozen_string_literal: true

module ExceptionHandler
  extend ActiveSupport::Concern

  included do
    rescue_from ActionController::ParameterMissing do |exc|
      Airbrake.notify(exc)
      render json: msg(exc), status: :bad_request
    end

    rescue_from ActiveRecord::RecordInvalid do |exc|
      Airbrake.notify(exc)
      render json: msg(exc), status: :unprocessable_entity
    end

    rescue_from ActiveRecord::RecordNotFound do |exc|
      Airbrake.notify(exc)
      render json: msg(exc), status: :not_found
    end

    rescue_from ActiveRecord::RecordNotUnique do |exc|
      Airbrake.notify(exc)
      render json: msg(exc), status: :unprocessable_entity
    end

    rescue_from ActiveRecord::RecordNotSaved do |exc|
      Airbrake.notify(exc)
      render json: msg(exc), status: :not_found
    end

    rescue_from ActiveRecord::Rollback do |exc|
      Airbrake.notify(exc)
      render json: msg(exc), status: :unprocessable_entity
    end

    rescue_from ActiveRecord::SubclassNotFound do |exc|
      Airbrake.notify(exc)
      render json: msg(exc), status: :bad_request
    end

    rescue_from CanCan::AccessDenied do |exc|
      Airbrake.notify(exc)
      render json: msg(exc), status: :forbidden
    end

    rescue_from Dentaku::Error do |exc|
      Airbrake.notify(exc)
      render json: msg(exc), status: :unprocessable_entity
    end
  end

  private

  def msg(exc)
    { message: exc.message }
  end
end
