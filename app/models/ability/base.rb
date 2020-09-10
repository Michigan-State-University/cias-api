# frozen_string_literal: true

class Ability::Base
  attr_reader :ability

  delegate :user, :can, :cannot, to: :ability
  delegate :role?, to: :user

  def initialize(ability)
    @ability = ability
  end

  def definition
    default if user.roles.present?
  end

  private

  def class_name
    self.class.name.demodulize.underscore
  end

  def default
    can %i[read update], User, id: user.id
    cannot :update, User, %i[deactivated roles]
  end
end
