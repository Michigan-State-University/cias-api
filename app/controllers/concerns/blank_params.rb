# frozen_string_literal: true

module BlankParams
  extend ActiveSupport::Concern

  included do
    def error_message_on_blank_param(params, params_names)
      params_names = Array(params_names)

      params_names.each do |attr|
        next unless -> { params.key?(attr) && params[attr].blank? }.call

        raise ArgumentError, attr.humanize
      end
    end

    rescue_from ArgumentError do |exc|
      render json: { message: "Param: #{exc.message} cannot be blank" }, status: :bad_request
    end
  end
end
