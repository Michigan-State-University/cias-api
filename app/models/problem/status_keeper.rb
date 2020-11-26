# frozen_string_literal: true

class Problem::StatusKeeper
  def initialize(problem_id)
    @problem_id = problem_id
  end

  def broadcast
    SessionJob::Broadcast.perform_later(problem_id)
  end

  private

  attr_reader :problem_id
end
