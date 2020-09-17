# frozen_string_literal: true

class UserIntervention < ApplicationRecord
  belongs_to :user, inverse_of: :user_interventions
  belongs_to :intervention, inverse_of: :user_interventions

  before_save :alter_schedule

  def alter_schedule
    return if intervention == intervention_next
    return if intervention_next&.schedule.nil?
    return unless intervention_next&.schedule_days_after_fill?
    return if submitted_at.nil?

    Intervention::Schedule.new(
      self,
      intervention_next,
      user_intervention_next
    ).days_after_fill
  end

  private

  def intervention_next
    @intervention_next ||= intervention.position_grather_than.first
  end

  def user_intervention_next
    @user_intervention_next ||= intervention_next.user_interventions.find_by(user_id: user_id)
  end
end
