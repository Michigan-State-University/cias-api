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
end
