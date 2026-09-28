# frozen_string_literal: true

class TestParticipants::PurgeTestParticipantsJob < ApplicationJob
  queue_as :test_participant_purge

  DEFAULT_RETENTION_MINUTES = 24 * 60

  def self.retention_window
    minutes = ENV.fetch('TEST_PARTICIPANT_RETENTION_MINUTES', DEFAULT_RETENTION_MINUTES).to_i

    (minutes.positive? ? minutes : DEFAULT_RETENTION_MINUTES).minutes
  end

  def perform(user_id)
    V1::Intervention::TestParticipants::PurgeService.call(user_id)
  end
end
