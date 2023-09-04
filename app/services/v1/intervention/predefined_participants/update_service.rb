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
      user.predefined_user_parameter.update(health_clinic_id: health_clinic_id) if health_clinic_id.present?
    end
    user
  end

  private

  attr_reader :params, :intervention
  attr_accessor :user

  def user_params
    params.except(:health_clinic_id)
  end

  def health_clinic_id
    @health_clinic_id ||= params[:health_clinic_id]
  end
end
