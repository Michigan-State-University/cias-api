# frozen_string_literal: true

class UserIntervention < ApplicationRecord
  has_paper_trail
  belongs_to :user, inverse_of: :user_interventions
  belongs_to :intervention, inverse_of: :user_interventions
  has_many :user_sessions, dependent: :destroy

  delegate :sessions, to: :intervention

  validates :health_clinic_id, presence: true, if: -> { intervention_inside_organization? && !preview? }

  enum status: { ready_to_start: 'ready_to_start', in_progress: 'in_progress', completed: 'completed', schedule_pending: 'schedule_pending' }

  def last_answer_date
    user_sessions.order(last_answer_at: :desc).first
  end

  def latest_user_sessions
    user_sessions.select('DISTINCT ON("session_id") *').order(:session_id, created_at: :desc, id: :desc)
  end

  def contain_multiple_fill_session
    sessions.multiple_fill.any?
  end

  def preview?
    user.role?('preview_session')
  end

  def intervention_inside_organization?
    intervention&.organization_id.present?
  end
end
