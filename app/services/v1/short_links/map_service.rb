# frozen_string_literal: true

class V1::ShortLinks::MapService
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
      intervention_id: intervention.id,
      session_id: nil,
      health_clinic_id: short_link.health_clinic_id,
      multiple_fill_session_available: true,
      user_intervention_id: user_intervention&.id
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
    UserIntervention.find_by(user_id: current_user.id, intervention_id: intervention.id)
  end

  def check_intervention_status
    return if intervention.published?

    raise ComplexException.new(I18n.t('short_link.error.not_available'), { reason: 'INTERVENTION_DRAFT' }, :bad_request) if intervention.draft?

    raise ComplexException.new(I18n.t('short_link.error.not_available'), { reason: 'INTERVENTION_CLOSED' }, :bad_request)
  end

  def check_intervention_access
    return if intervention.shared_to_anyone?

    if !current_user&.role?('participant') && intervention.shared_to_registered?
      raise ComplexException.new(I18n.t('short_link.error.only_registered'), { reason: 'ONLY_REGISTERED' },
                                 :unauthorized)
    end
    if intervention.shared_to_invited? && !intervention.intervention_accesses.pluck(:email).include?(current_user&.email)
      raise ComplexException.new(I18n.t('short_link.error.only_invited'), { reason: 'ONLY_INVITED' },
                                 :forbidden)
    end
  end
end
