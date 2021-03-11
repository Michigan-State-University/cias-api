# frozen_string_literal: true

class V1::Intervention::Publish
  def initialize(intervention)
    @intervention = intervention
    @sessions = intervention.sessions.order(:position)
  end

  def execute
    timestamp_published_at
    calculate_days_after_schedule
    delete_draft_answers
    delete_preview_data
  end

  private

  attr_accessor :intervention
  attr_reader :sessions

  def timestamp_published_at
    intervention.update!(published_at: Time.current)
  end

  def calculate_days_after_schedule
    schedule_time = DateTime.current
    sessions.each do |session|
      next if session.schedule == 'after_fill'

      if session.schedule == 'exact_date'
        schedule_time = session.schedule_at
        next
      end

      schedule_time += session.schedule_payload.days
      next if session.schedule == 'days_after_fill'

      if session.schedule == 'days_after'
        session.schedule_at = schedule_time.to_s
        session.save!
      end
    end
  end

  def delete_draft_answers
    Answer.joins(question: { question_group: :session }).where(
      questions: { question_groups: { sessions: { intervention_id: intervention.id } } }
    ).destroy_all
  end

  def delete_preview_data
    session_ids = intervention.sessions.select(:id)
    preview_users = User.where(preview_session_id: session_ids)
    preview_user_ids = preview_users.select(:id)
    UserSession.where(user_id: preview_user_ids).delete_all
    UserLogRequest.where(user_id: preview_user_ids).delete_all
    Phone.where(user_id: preview_user_ids).delete_all
    preview_users.delete_all
  end
end
