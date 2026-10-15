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
      lang: intervention.language_code,
      ra_session_pending: ra_session_pending?,
      intervention_type: intervention.type
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

  def ra_session_pending?
    ra = ra_session(intervention)
    return false if ra.nil?

    ra_user_session = UserSession.find_by(
      session_id: ra.id,
      user_id: predefined_user_parameters.user_id
    )
    ra_user_session.nil? || ra_user_session.finished_at.nil?
  end
end
