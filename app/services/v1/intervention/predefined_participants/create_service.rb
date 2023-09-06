# frozen_string_literal: true

class V1::Intervention::PredefinedParticipants::CreateService
  def initialize(intervention, params)
    @intervention = intervention
    @params = params
  end

  def self.call(intervention, params)
    new(intervention, params).call
  end

  def call
    ActiveRecord::Base.transaction do
      user = create_predefined_user!
      Phone.create!(phone_params.merge({ user: user })) if phone_params
      PredefinedUserParameter.create!(predefined_user_parameter_params.merge({ user: user, intervention: intervention }))
      user
    end
  end

  private

  attr_reader :params, :intervention

  def phone_params
    params[:phone_attributes]
  end

  def predefined_user_parameter_params
    params.slice(:health_clinic_id, :auto_invitation)
  end

  def create_predefined_user!
    User.new.tap do |user|
      user.roles = %w[predefined_participant]
      user.skip_confirmation!
      user.email = "#{Time.current.to_i}_#{SecureRandom.hex(10)}@predefined-participant.true"
      user.first_name = params[:first_name]
      user.last_name = params[:last_name]
      user.save(validate: false)
    end
  end
end
