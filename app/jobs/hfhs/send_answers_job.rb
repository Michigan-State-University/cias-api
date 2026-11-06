# frozen_string_literal: true

class Hfhs::SendAnswersJob < ApplicationJob
  queue_as :hfhs

  def perform(user_session_id)
    user_session = UserSession.find_by(id: user_session_id)
    return if user_session.nil? || test_run?(user_session) || unverified_patient?(user_session)

    api = Api::Hfhs.new
    api.send_answers(user_session_id)
    api.send_reports(user_session_id)
  end

  private

  def test_run?(user_session)
    return false unless user_session.user&.test_run?

    Rails.logger.warn(
      '[Hfhs::SendAnswersJob] skipped HFHS transmission for a test run ' \
      "user_session_id=#{user_session.id} user_id=#{user_session.user_id}"
    )
    true
  end

  def unverified_patient?(user_session)
    return false if user_session.user&.hfhs_patient_detail_id?

    Rails.logger.warn(
      '[Hfhs::SendAnswersJob] skipped HFHS transmission for a patient without verified HFHS details ' \
      "user_session_id=#{user_session.id} user_id=#{user_session.user_id}"
    )
    true
  end
end
