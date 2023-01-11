# frozen_string_literal: true

class UserIntervention < ApplicationRecord
  has_paper_trail
  belongs_to :user, inverse_of: :user_interventions
  belongs_to :intervention, inverse_of: :user_interventions
  has_many :user_sessions, dependent: :destroy

  delegate :sessions, to: :intervention

  enum status: { ready_to_start: 'ready_to_start', in_progress: 'in_progress', completed: 'completed', schedule_pending: 'schedule_pending' }

  def last_answer_date
    user_sessions.order(last_answer_at: :desc).first
  end
end
