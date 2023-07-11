# frozen_string_literal: true

class Ability::Base
  attr_reader :ability

  delegate :user, :can, :cannot, to: :ability
  delegate :role?, to: :user

  def initialize(ability)
    @ability = ability
  end

  def definition
    can %i[read update], User, id: user.id
    cannot :update, User, %i[deactivated roles]
  end

  private

  def class_name
    self.class.name.demodulize.underscore
  end

  def researchers_from_team(team_id)
    team_id ? User.researchers.from_team(team_id).pluck(:id) : User.none
  end

  def e_intervention_admins_from_organization(organization_id)
    organization_id ? User.e_intervention_admins.where(organizable_id: organization_id).pluck(:id) : User.none
  end

  def participants_with_answers(user)
    user_interventions = logged_user_intervention(user)
    return User.none if user_interventions.blank?

    User.participants.left_joins(:user_interventions).where(user_interventions: { intervention_id: user_interventions })
        .distinct.pluck(:id)
  end

  def participants_and_researchers(user)
    participants_with_answers(user) + researchers_from_team(user.team_id)
  end

  def participants_researchers_and_e_intervention_admins(user)
    participants_and_researchers(user) + e_intervention_admins_from_organization(user.organizable_id)
  end

  def researchers_and_e_intervention_admins(user)
    researchers_from_team(user.team_id) + e_intervention_admins_from_organization(user.accepted_organization_ids)
  end

  def logged_user_session_ids(user)
    logged_user_sessions(user).pluck(:id)
  end

  def logged_user_sessions(user)
    Session.where(intervention_id: user.interventions.select(:id))
  end

  def logged_user_intervention(user)
    user.interventions
        .left_joins(:collaborators)
        .or(Intervention.left_joins(:collaborators).where(collaborators: { user_id: user.id, data_access: true }))
        .select(:id)
  end

  def accepted_health_clinic_ids
    return unless user.role?('health_clinic_admin')

    health_clinic_ids = user.health_clinic_invitations.where.not(accepted_at: nil).map(&:health_clinic_id)
    health_clinic_ids.append(user.organizable.id) if user.organizable
    health_clinic_ids
  end
end
