# frozen_string_literal: true

class TestParticipants::StrandedPurgesQuery
  def self.call(now = Time.current)
    new(now).call
  end

  def initialize(now = Time.current)
    @now = now
  end

  # The beginless range excludes NULLs, so a marked user whose purge was never scheduled is not a candidate.
  def call
    User.where(test_run: true)
        .where.not(test_run_intervention_id: nil)
        .where(purge_scheduled_at: ...now)
  end

  private

  attr_reader :now
end
