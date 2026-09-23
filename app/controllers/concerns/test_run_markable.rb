# frozen_string_literal: true

# Mixed into the public, unauthenticated fill entry points. A guest whose request carries a valid
# test-link token is flagged as a researcher test run; anything wrong with the token (missing,
# malformed, tampered, expired) is ignored so a stale link still lets a real participant fill the
# session.
#
# The hook is invoked explicitly from the fill actions, *after* their `authorize!` call, rather
# than from guest resolution: resolving the intervention reads `params.require(...)`, which is only
# safe on the actions that carry that body, and a request that authorization rejects has no fill to
# decorate.
module TestRunMarkable
  private

  # Never raises. The whole point of the marker is that it is optional decoration on somebody
  # else's request — a token problem, a missing param or a database hiccup must degrade the fill to
  # an ordinary non-test fill, never break it.
  def mark_test_run(user)
    token = test_link_token_param
    return false if token.blank?

    V1::TestRuns::MarkGuest.call(user, test_run_intervention_id, token)
  rescue StandardError => e
    Rails.logger.warn("[TestRunMarkable] skipped test-run marking: #{e.class}")
    Sentry.capture_exception(e)
    false
  end

  # Whether *this* fill is test data — not merely whether this request did the marking. A researcher
  # who clicks "Start session again" gets a brand-new guest, so the client cannot infer it: the
  # backend fails open, and a refused marker is byte-for-byte indistinguishable from a successful one
  # unless we say so. Reported on `user_sessions#create`, `#show_or_create` and
  # `user_interventions#create`, so the absence of a marker is as visible as its presence.
  #
  # Two subtleties, both load-bearing:
  #
  # * `test_run_in_database`, not `test_run?` — `MarkGuest` marks with `update!`, which assigns and
  #   then saves. A save that blows up leaves the in-memory object claiming `true` while the row says
  #   `false`, and this runs on that very object moments later.
  # * `user.test_run_intervention_id` (which intervention the marker covers) is compared against
  #   `test_run_intervention_id` (the private method below: which intervention this request fills).
  #   Same name, different things — do not collapse them. One guest identity legitimately spans
  #   several "anyone with the link" interventions, and `PurgeService` only ever deletes the fills of
  #   the marked one, so reporting `true` for a *different* intervention would promise a deletion
  #   that never comes.
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
