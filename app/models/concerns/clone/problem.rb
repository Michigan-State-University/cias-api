# frozen_string_literal: true

class Clone::Problem < Clone::Base
  def execute
    outcome.to_initial
    outcome.save!
    create_sessions
    outcome
  end

  private

  def create_sessions
    source.sessions.each do |session|
      Clone::Session.new(session, problem_id: outcome.id).execute
    end
  end
end
