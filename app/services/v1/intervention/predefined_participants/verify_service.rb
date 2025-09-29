# frozen_string_literal: true

class V1::Intervention::PredefinedParticipants::VerifyService
  include StaticLinkHelper

  def initialize(predefined_user_parameters)
    @predefined_user_parameters = predefined_user_parameters
  end

  def self.call(predefined_user_parameters)
    new(predefined_user_parameters).call
  end

  def call
    {
      intervention_id: predefined_user_parameters.intervention_id,
      session_id: available_now_session(intervention, user_intervention)&.id,
      health_clinic_id: health_clinic_id,
      multiple_fill_session_available: multiple_fill_session_available?(user_intervention),
      user_intervention_id: user_intervention.id,
      lang: intervention.language_code
    }
  end

  attr_reader :predefined_user_parameters

  private

  def user_intervention
    @user_intervention ||= UserIntervention.find_or_create_by(user_id: predefined_user_parameters.user_id, intervention_id: intervention.id,
                                                              health_clinic_id: health_clinic_id)
  end

  def intervention
    @intervention ||= predefined_user_parameters.intervention
  end

  def health_clinic_id
    @health_clinic_id ||= predefined_user_parameters.health_clinic_id
  end
end
