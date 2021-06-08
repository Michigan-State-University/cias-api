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
    team_id ? User.researchers.where(team_id: team_id).pluck(:id) : User.none
  end

  def participants_with_answers(user)
    result = logged_user_sessions(user)
    return User.none if result.blank?

    User.participants.select { |participant| Answer.user_answers(participant.id, result).any? }.pluck(:id)
  end

  def participants_and_researchers(user)
    participants_with_answers(user) + researchers_from_team(user.team_id)
  end

  def logged_user_sessions(user)
    Session.where(intervention_id: user.interventions.select(:id)).pluck(:id)
  end
end
