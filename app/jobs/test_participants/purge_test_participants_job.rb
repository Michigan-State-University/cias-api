# frozen_string_literal: true

class TestParticipants::PurgeTestParticipantsJob < ApplicationJob
  queue_as :test_participant_purge

  RETENTION_WINDOW = 24.hours

  def perform(user_id)
    V1::Intervention::TestParticipants::PurgeService.call(user_id)
  end
end
