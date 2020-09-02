# frozen_string_literal: true

class Ability::Participant < Ability::Base
  def definition
    super
    participant if role?(class_name)
  end

  private

  def participant
    can :read, Problem, Problem.joins(:user_problems).not_shared_to_invited.or(Problem.joins(:user_problems).where(user_problems: { user_id: user.id })) do |problem|
      !problem.shared_to_invited? || problem.user_problems.where(user_id: user.id).any?
    end
  end
end
