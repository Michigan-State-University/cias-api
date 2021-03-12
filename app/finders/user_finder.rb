# frozen_string_literal: true

class UserFinder
  def self.available_researchers(current_user, filter_params = {})
    new(current_user, filter_params).available_researchers
  end

  def initialize(current_user, filter_params)
    @filter_params = filter_params
    @current_user = current_user
    @scope = User.all
  end

  def available_researchers
    return User.researchers if admin?
    return User.none unless permitted_roles?
    return User.none if researcher_without_team?

    scope.researchers.from_team(
      team_ids
    )
  end

  private

  attr_reader :filter_params, :current_user, :scope

  def team_ids
    if team_admin?
      current_user.admins_team_ids
    elsif researcher?
      current_user.team_id
    end
  end

  def permitted_roles?
    researcher? || team_admin?
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
end
