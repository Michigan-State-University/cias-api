# frozen_string_literal: true

class UserFinder
  def self.available_researchers(current_user, filter_params = {})
    new(current_user, filter_params).available_researchers
  end

  def initialize(current_user, filter_params)
    @filter_params = filter_params
    @current_user = current_user
    @scope = User.where.not(id: current_user.id)
  end

  def available_researchers
    return User.with_intervention_creation_access if admin?
    return User.none unless permitted_role?

    scope.with_intervention_creation_access.from_team_or_organization(team_ids, organization_ids)
  end

  private

  attr_reader :filter_params, :current_user, :scope

  def organization_ids
    current_user.accepted_organization_ids
  end

  def team_ids
    if team_admin?
      current_user.admins_team_ids
    elsif researcher? || e_intervention_admin?
      current_user.team_id
    end
  end

  def permitted_role?
    researcher?
  end

  def researcher_without_team?
    researcher? && current_user.team_id.blank?
  end

  def researcher?
    current_user.role?('researcher')
  end

  def team_admin?
    current_user.role?('team_admin')
  end

  def admin?
    current_user.role?('admin')
  end

  def e_intervention_admin?
    current_user.role?('e_intervention_admin')
  end
end
