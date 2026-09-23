# frozen_string_literal: true

class Hfhs::SendAnswersJob < ApplicationJob
  queue_as :hfhs

  def perform(user_session_id)
    return if test_run?(user_session_id)

    api = Api::Hfhs.new
    api.send_answers(user_session_id)
    api.send_reports(user_session_id)
  end

  private

  # `find_by`: a purge can destroy the session between the enqueue at finish and this running. Nothing to send either way.
  def test_run?(user_session_id)
    user_session = UserSession.find_by(id: user_session_id)
    return true if user_session.nil?

    return false unless user_session.user&.test_run?

    Rails.logger.warn(
      '[Hfhs::SendAnswersJob] skipped HFHS transmission for a test run ' \
      "user_session_id=#{user_session_id} user_id=#{user_session.user_id}"
    )
    true
  end
end
