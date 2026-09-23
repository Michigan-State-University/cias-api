# frozen_string_literal: true

# Removes one marked test participant by handing its user id to
# `V1::Intervention::TestParticipants::PurgeService`. It is a fuse lit at marking time — scheduled
# one `RETENTION_WINDOW` ahead — so a researcher's test fill disappears on its own roughly a day
# later, with no researcher action and no confirmation step (decisions D6 and D7).
#
# `V1::TestRuns::MarkGuest` lights that fuse: the instant the marker is persisted it enqueues this
# job for `RETENTION_WINDOW.from_now` and stamps that same instant on `users.purge_scheduled_at`.
# The two are deliberately one value, not two calculations that agree — `purge_scheduled_at` is
# what `TestParticipants::StrandedPurgesQuery` keys on to find purges that fell due and never ran,
# so a stamp later than the real firing time hides a stranding and an earlier one re-enqueues a
# purge that is still perfectly alive in Redis.
#
# This is an unattended, irreversible deletion path. It went live only once its preconditions were
# discharged — SEC-R2-1 (a genuine anonymous participant's fill can be mis-marked `test_run` on a
# shared device) accepted and ADJ-1 fixed on 2026-09-23, decision D13, with SEC-1 (a purged
# answer's plaintext body survives in `versions`) closed as subsumed and tracked app-wide.
#
# **Scoping lives in `PurgeService`, and deliberately so.** This job takes exactly one user id and
# never selects candidates itself. A bare `User.where(test_run: true)` sweep would be unsafe:
# `users.test_run` is a user-level flag while the test link that sets it is minted per intervention,
# and one anonymous guest identity legitimately spans several "anyone with the link" interventions.
# `PurgeService` re-reads the marker under a row lock, refuses a marker carrying no
# `test_run_intervention_id` (`:unscoped_marker`), and intersects every destroy with it — so a link
# minted for intervention A can never reach that guest's genuine fills of intervention B. Any
# pre-filtering here would only duplicate that check and race with it.
#
# Idempotent by delegation: the service returns a `skip_reason` Result rather than raising for a
# user that was already purged (`:already_purged`), was un-marked between scheduling and execution
# (`:not_marked`), or cannot be scoped (`:unscoped_marker`). Re-running the job is a clean no-op.
class TestParticipants::PurgeTestParticipantsJob < ApplicationJob
  # Its own queue at weight 1 (work item 2.10) rather than the shared `:default` at weight 4, so a
  # burst of purges can neither starve nor be starved by interactive work. The name has to stay in
  # step with `config/sidekiq.yml` — a typo on either side enqueues into a queue no worker polls,
  # and the purge silently never runs.
  queue_as :test_participant_purge

  # How long a marked test participant survives before it is destroyed. Fixed at marking time and
  # **not** configurable (assumption A3). `V1::TestRuns::MarkGuest` resolves this once and uses the
  # resulting instant for both the `wait_until:` and the `purge_scheduled_at` stamp, keeping the fuse
  # and the durable record of it the same value.
  RETENTION_WINDOW = 24.hours

  def perform(user_id)
    V1::Intervention::TestParticipants::PurgeService.call(user_id)
  end
end
