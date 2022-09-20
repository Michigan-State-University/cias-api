# frozen_string_literal: true

class V1::Auth::RegistrationsController < DeviseTokenAuth::RegistrationsController
  include Resource
  include Log
  prepend Auth::Default

  def create
    if valid_names?
      super
    else
      render json: { message: I18n.t('activerecord.errors.models.user.attributes.blank_attr.attr_cannot_be_blank',
                                     attr: 'First name and last name') }, status: :unprocessable_entity
    end
  end

  private

  def valid_names?
    [first_name, last_name].each do |attr|
      return false if attr.blank?
    end
  end

  def first_name
    params['first_name']
  end

  def last_name
    params['last_name']
  end
end
