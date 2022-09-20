# frozen_string_literal: true

class V1::Auth::RegistrationsController < DeviseTokenAuth::RegistrationsController
  include Resource
  include Log
  prepend Auth::Default

  def create
    return if invalid_names?

    super
  end

  private

  def invalid_names?
    invalid_attr = []
    %w[first_name last_name].each do |attr|
      next if params[attr].present?

      invalid_attr << attr
    end
    return false if invalid_attr.blank?

    render json: { message: I18n.t('activerecord.errors.models.user.attributes.blank_attr.attr_cannot_be_blank',
                                   attr: invalid_attr.join(' and ').humanize) }, status: :unprocessable_entity
  end
end
