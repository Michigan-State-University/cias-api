# frozen_string_literal: true

module BlankParams
  extend ActiveSupport::Concern
  include ExceptionHandler

  def error_message_on_blank_param(params, params_names)
    params_names = Array(params_names)

    params_names.each do |attr|
      next unless -> { params.key?(attr) && params[attr].blank? }.call

      raise ActionController::ParameterMissing, "#{attr.humanize} cannot be blank"
    end
  end
end
