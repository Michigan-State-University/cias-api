# frozen_string_literal: true

# Call `mark_test_run` from the fill actions after `authorize!`, never from guest resolution.
module TestRunMarkable
  private

  # Must never raise: a failed marker degrades the fill, it does not break it.
  def mark_test_run(user)
    token = test_link_token_param
    return false if token.blank?

    V1::TestRuns::MarkGuest.call(user, test_run_intervention_id, token)
  rescue StandardError => e
    Rails.logger.warn("[TestRunMarkable] skipped test-run marking: #{e.class}")
    Sentry.capture_exception(e)
    false
  end

  # `test_run_in_database`: a failed `update!` leaves the object claiming `true`.
  # The two `test_run_intervention_id`s differ — marker's vs this request's. Do not collapse.
  def test_run_meta(user)
    {
      test_run: user.present? &&
        user.test_run_in_database &&
        user.test_run_intervention_id == test_run_intervention_id
    }
  end

  def test_link_token_param
    params[:test_link_token].presence
  end

  def test_run_intervention_id
    intervention&.id
  end
end
