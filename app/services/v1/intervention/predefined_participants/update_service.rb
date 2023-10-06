# frozen_string_literal: true

class V1::Intervention::PredefinedParticipants::UpdateService
  def initialize(intervention, user, params)
    @intervention = intervention
    @user = user
    @params = params
  end

  def self.call(intervention, user, params)
    new(intervention, user, params).call
  end

  def call
    ActiveRecord::Base.transaction do
      user.update!(user_params)
      user.predefined_user_parameter.update(predefined_user_parameters)
      remove_phone! if predefined_user_parameters[:phone_attributes].blank?
    end
    user
  end

  private

  attr_reader :params, :intervention
  attr_accessor :user

  def user_params
    params.except(:health_clinic_id, :external_id, :auto_invitation)
  end

  def predefined_user_parameters
    params.except(:first_name, :last_name, :active, :email, :phone_attributes)
  end

  def health_clinic_id
    @health_clinic_id ||= params[:health_clinic_id]
  end

  def remove_phone!
    user.phone&.destroy!
  end
end
