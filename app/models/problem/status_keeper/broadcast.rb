# frozen_string_literal: true

class Problem::StatusKeeper::Broadcast
  def initialize(problem)
    @problem = problem
  end

  def execute
    timestamp_published_at
    calculate_schedule_days_after
    delete_draft_answers
    mails_grant_access_to_a_user
  end

  private

  attr_accessor :problem

  def timestamp_published_at
    problem.update!(published_at: Time.current)
  end

  def calculate_schedule_days_after
    ::Intervention::Schedule.new(
      problem.interventions.order(:position),
      problem.published_at
    ).days_after
  end

  def delete_draft_answers
    Answer.joins(question: :intervention).where(
      questions: { interventions: { problem_id: problem.id } }
    ).destroy_all
  end

  def mails_grant_access_to_a_user
    problem.user_interventions.each do |user_inter|
      InterventionMailer.grant_access_to_a_user(
        user_inter.intervention,
        user_inter.email
      ).deliver_now
    end
  end
end
