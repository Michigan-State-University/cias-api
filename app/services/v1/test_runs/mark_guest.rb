# frozen_string_literal: true

class V1::TestRuns::MarkGuest
  def self.call(user, intervention_id, token)
    new(user, intervention_id, token).call
  end

  def initialize(user, intervention_id, token)
    @user = user
    @intervention_id = intervention_id
    @token = token
  end

  def call
    return false unless markable?

    payload = V1::TestRuns::LinkToken.verify(token, intervention_id)
    return false if payload.blank?

    persist!(payload)
    true
  rescue StandardError => e
    Rails.logger.warn("[V1::TestRuns::MarkGuest] test-run marking did not complete: #{e.class}")
    Sentry.capture_exception(e)
    false
  end

  private

  attr_reader :user, :intervention_id, :token

  # One instant for both `wait_until:` and `purge_scheduled_at`, so `StrandedPurgesQuery` cannot disagree with the job.
  def persist!(payload)
    purge_at = TestParticipants::PurgeTestParticipantsJob::RETENTION_WINDOW.from_now

    user.update!(
      test_run: true,
      test_run_intervention_id: intervention_id,
      test_run_marked_by_id: payload['minted_by_id'],
      purge_scheduled_at: purge_at
    )

    TestParticipants::PurgeTestParticipantsJob.set(wait_until: purge_at).perform_later(user.id)
  end

  # Guests only, and only one created within the token's own lifetime — never a kiosk guest already holding real data.
  def markable?
    return false if token.blank? || intervention_id.blank?
    return false unless user.present? && user.role?('guest') && !user.test_run?

    user.created_at.present? && user.created_at > V1::TestRuns::LinkToken.ttl.ago
  end
end
