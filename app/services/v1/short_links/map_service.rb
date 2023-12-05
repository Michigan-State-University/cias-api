# frozen_string_literal: true

class V1::ShortLinks::MapService
  include StaticLinkHelper

  def initialize(name, current_user)
    @name = name
    @current_user = current_user
  end

  def self.call(name, current_user)
    new(name, current_user).call
  end

  attr_reader :name, :current_user

  def call
    check_intervention_status
    check_intervention_access

    {
      data: {
        intervention_id: intervention.id,
        session_id: available_now_session(intervention, user_intervention)&.id,
        health_clinic_id: short_link.health_clinic_id,
        multiple_fill_session_available: multiple_fill_session_available(user_intervention),
        user_intervention_id: user_intervention&.id
      }
    }.to_json
  end

  private

  def first_session_id
    return nil unless object.type.eql?('Intervention')

    object.sessions.order(:position).first&.id
  end

  def object
    @object ||= short_link.linkable
  end

  def short_link
    @short_link ||= ShortLink.find_by!(name: name)
  end

  def intervention
    @intervention ||= Intervention.joins(:short_links).find_by!(short_links: { name: name })
  end

  def user_intervention
    @user_intervention ||= UserIntervention.find_by(user_id: current_user&.id, intervention_id: intervention.id)
  end

  def check_intervention_status
    return if intervention.published?

    raise ComplexException.new(I18n.t('short_link.error.not_available'), { reason: 'INTERVENTION_DRAFT' }, :bad_request) if intervention.draft?

    raise ComplexException.new(I18n.t('short_link.error.not_available'), { reason: 'INTERVENTION_PAUSED' }, :bad_request) if intervention.paused?

    raise ComplexException.new(I18n.t('short_link.error.not_available'), { reason: 'INTERVENTION_CLOSED' }, :bad_request)
  end

  def check_intervention_access
    return if intervention.shared_to_anyone?

    handle_access_denied unless allowed_access?(intervention, current_user)
  end

  def allowed_access?(intervention, current_user)
    return true if current_user&.role?('participant') && intervention.shared_to_registered?
    return true if intervention.shared_to_invited? && invited_user?(intervention, current_user)

    false
  end

  def invited_user?(intervention, current_user)
    intervention.intervention_accesses.pluck(:email).include?(current_user&.email)
  end

  def handle_access_denied
    unless current_user&.role?('participant')
      raise ComplexException.new(I18n.t('short_link.error.only_registered'), { reason: 'ONLY_REGISTERED' },
                                 :unauthorized)
    end

    raise ComplexException.new(I18n.t('short_link.error.only_invited'), { reason: 'ONLY_INVITED' }, :forbidden)
  end
end
