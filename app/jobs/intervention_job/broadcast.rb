# frozen_string_literal: true

class InterventionJob::Broadcast < InterventionJob
  def perform(problem_id)
    Problem::StatusKeeper::Broadcast.new(
      Problem.find(problem_id)
    ).execute
  end
end
