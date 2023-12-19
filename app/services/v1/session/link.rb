# frozen_string_literal: true

class V1::Session::Link
  attr_reader :user, :session, :health_clinic

  def initialize(session, health_clinic, email)
    @session = session
    @health_clinic = health_clinic
    @user = User.find_by!(email: email)
  end

  def self.call(session, health_clinic, email)
    new(session, health_clinic, email).call
  end

  def call
    return "#{ENV['WEB_URL']}/usr/#{user.predefined_user_parameter.slug}" if user&.roles&.include?('predefined_participant')

    if session.intervention.shared_to_anyone?
      (if health_clinic.nil?
         I18n.t('session_mailer.inform_to_an_email.invitation_link_for_anyone',
                domain: ENV['WEB_URL'], session_id: session.id,
                intervention_id: session.intervention_id)
       else
         I18n.t('session_mailer.inform_to_an_email.invitation_link_for_anyone_from_clinic',
                domain: ENV['WEB_URL'], session_id: session.id,
                intervention_id: session.intervention_id,
                health_clinic_id: health_clinic.id)
       end)
    else
      (if health_clinic.nil?
         I18n.t('session_mailer.inform_to_an_email.invitation_link',
                domain: ENV['WEB_URL'],
                intervention_id: session.intervention_id, session_id: session.id)
       else
         I18n.t('session_mailer.inform_to_an_email.invitation_link_from_clinic',
                domain: ENV['WEB_URL'],
                intervention_id: session.intervention_id, session_id: session.id,
                health_clinic_id: health_clinic.id)
       end)
    end
  end
end
