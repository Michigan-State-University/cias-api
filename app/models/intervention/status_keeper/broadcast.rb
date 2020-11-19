# frozen_string_literal: true

class Intervention::StatusKeeper::Broadcast
  def initialize(intervention)
    @intervention = intervention
    @sessions = intervention.sessions.order(:position)
  end

  def execute
    timestamp_published_at
    calculate_schedule_days_after
    delete_draft_answers
    mails_grant_access_to_a_user
  end

  private

  attr_accessor :intervention
  attr_reader :sessions

  def timestamp_published_at
    intervention.update!(published_at: Time.current)
  end

  def calculate_schedule_days_after
    ::Session::Schedule.new(
      sessions,
      intervention.published_at
    ).days_after
  end

  def delete_draft_answers
    Answer.joins(question: { question_group: :session }).where(
      questions: { question_groups: { sessions: { intervention_id: intervention.id } } }
    ).destroy_all
  end

  def mails_grant_access_to_a_user
    intervention.user_sessions.each do |user_inter|
      SessionMailer.grant_access_to_a_user(
        user_inter.session,
        user_inter.user.email
      ).deliver_now
    end
  end
end
