# frozen_string_literal: true

# Permanently removes one marked test participant's contribution to a single intervention — its
# sessions, answers, generated reports, live-chat conversations and, critically, its
# `ChartStatistic` rows, so the dashboard recomputes without it. Destruction is irreversible and
# there is no grace window; that is the decided model for this feature, not an oversight.
#
# **Scoping is the whole game.** `users.test_run` is a *user-level* flag, but the test link that
# sets it is minted for one intervention, and a single anonymous guest identity legitimately spans
# several "anyone with the link" interventions belonging to different researchers. Every query below
# therefore intersects `users.test_run_intervention_id`: a link minted for intervention A must never
# reach that guest's genuine fills of intervention B. A marked user carrying no
# `test_run_intervention_id` cannot be scoped at all, so it is refused rather than purged broadly.
#
# **Destruction order is load-bearing.** It was derived from the live schema by
# `.claude/cias-api/testing/test_participant_purge_cascade_spike.rb`, which catalogues every inbound
# foreign key on `users` / `user_sessions` / `user_interventions` and proves each failure mode:
#
#   1. `chart_statistics` and `sms_campaign_events` reference `user_sessions` with neither an
#      `ON DELETE` action nor a Rails `dependent:` — both raise `ActiveRecord::InvalidForeignKey`
#      unless they are removed first.
#   2. Live-chat conversations do **not** hang off `user_sessions`; they hang off the intervention,
#      and `User#interlocutors` is `dependent: :restrict_with_exception`. The conversation has to go
#      explicitly, as a whole — destroying only the guest's interlocutor would orphan
#      `live_chat_messages`, which reference it with no `ON DELETE` action either.
#   3. `sms_links_users` references `users` with neither an `ON DELETE` action nor an association.
#   4. Only then can the `user_interventions` cascade run
#      (`UserSession → Answer / GeneratedReport / Tlfb::Day`), and only then can the user shell go.
#
# The spike reports five such unguarded constraints in total. Two are unreachable for an anonymous
# guest and are deliberately left alone rather than handled: `interventions.current_editor_id` (a
# guest never edits an intervention) and `user_sessions.fulfilled_by_id` (a guest is never a research
# assistant filling a session on someone else's behalf). Both are still checked by `orphaned?`,
# because that is an assumption about product behaviour and not something the schema enforces.
#
# `user.destroy` is **never** called: `interventions`, `user_interventions`, `user_sessions`,
# `sessions` and `interlocutors` are all `dependent: :restrict_with_exception`, so it raises for
# anyone who has ever filled a session — i.e. for every test participant. The shell is removed with
# `User.where(...).destroy_all` once it is a genuine orphan, and deliberately left in place when the
# guest still holds data for another intervention.
class V1::Intervention::TestParticipants::PurgeService
  prepend Database::Transactional

  # Suppressing the audit trail for the cascade is deliberate (work item 2.9): a purge would
  # otherwise write thousands of `audits` / `versions` rows describing data that no longer exists.
  #
  # `Model.without_auditing` writes to `Audited.store`, which is an `ActiveSupport::CurrentAttributes`
  # subclass and therefore isolated per thread — safe inside a threaded Sidekiq process. The
  # module-level `Audited.auditing_enabled=` is a plain process-global accessor and would silently
  # disable auditing for every other job running alongside this one, so it is not used.
  #
  # The list is explicit because auditing is enabled per table, not per hierarchy — `ApplicationRecord`
  # cannot switch it off for its descendants. STI subclasses share their parent's `table_name`, so
  # `UserSession` also covers `UserSession::Classic` and `Answer` covers every answer type. A model
  # missing from this list still purges correctly; it just leaves audit rows behind.
  #
  # `Audio` is in the list even though the purge never destroys one: `UserSession::ClassicBehavior`
  # decrements the narrator audio's usage counter in a `before_destroy`, so destroying a session
  # with a `name_audio` *updates* an `Audio` and writes an audit for it.
  AUDIT_SUPPRESSED_MODELS = [
    User, UserIntervention, UserSession, Answer, GeneratedReport, GeneratedReportsThirdPartyUser,
    DownloadedReport, ChartStatistic, SmsCampaignEvent, SmsLinksUser,
    Tlfb::Day, Tlfb::Event, Tlfb::ConsumptionResult, Audio,
    LiveChat::Conversation, LiveChat::Interlocutor, LiveChat::Message, LiveChat::SummoningUser,
    Notification, Phone, UserVerificationCode
  ].freeze

  Result = Struct.new(:purged, :user_destroyed, :skip_reason, :counts, keyword_init: true) do
    def purged?
      purged
    end

    def user_destroyed?
      user_destroyed
    end
  end

  def self.call(user_id)
    new(user_id).call
  end

  def initialize(user_id)
    @user_id = user_id
  end

  def call
    # Re-read under a row lock rather than trusting whatever the caller scheduled against: a
    # participant un-marked between scheduling and execution must survive, and a concurrent purge
    # of the same user must not interleave with this one.
    user = User.lock.find_by(id: user_id)

    return skipped(:already_purged) if user.nil?
    return skipped(:not_marked) unless user.test_run?
    return skipped(:unscoped_marker) if user.test_run_intervention_id.blank?

    purge(user)
  end

  private

  attr_reader :user_id

  def purge(user)
    intervention_id = user.test_run_intervention_id
    # Read before the destroy block: after it, the row this came from may not exist.
    marked_by_id = user.test_run_marked_by_id
    counts = {}

    without_audit_trail do
      counts = destroy_scoped_data(user, intervention_id)
      counts[:users] = destroy_shell_or_release_marker(user)
    end

    result = Result.new(purged: true, user_destroyed: counts[:users].positive?, skip_reason: nil, counts: counts)
    log_purge(user.id, intervention_id, marked_by_id, result)

    result
  end

  # The only durable trace a purge leaves. The audit trail is deliberately suppressed for the
  # cascade and the destroyed rows take their own history with them, so without this line there is
  # no record anywhere that participant data was deleted, by whose link, or how much of it.
  #
  # PHI-free by construction: UUIDs, booleans and integers only — no names, emails, phone numbers,
  # answer bodies or any `has_encrypted` attribute. Emitted inside `Database::Transactional`'s
  # transaction, so it can over-report: `ApplicationJob`'s 30-minute `Timeout` can still fire between
  # here and the commit, which would roll the purge back after this line was written.
  #
  # `warn`, not `info`: production runs `config.log_level = :warn`, so an `info` line is never
  # written there at all — the skip path below already logs at `warn`, which would have left
  # refusals visible and actual deletions invisible.
  def log_purge(purged_user_id, intervention_id, marked_by_id, result)
    Rails.logger.warn(
      '[TestParticipants::PurgeService] purged ' \
      "user_id=#{purged_user_id} intervention_id=#{intervention_id} marked_by_id=#{marked_by_id} " \
      "user_destroyed=#{result.user_destroyed?} counts=#{result.counts}"
    )
  end

  # Everything here is scoped to `intervention_id`. Each `destroy_all` returns the rows it removed,
  # so the counts report what actually happened rather than what was queued. The steps are written
  # out one per line rather than collected in a hash literal because the order between them is the
  # point of this service.
  def destroy_scoped_data(user, intervention_id)
    user_interventions = UserIntervention.where(user_id: user.id, intervention_id: intervention_id)
    user_sessions = UserSession.where(user_intervention_id: user_interventions.select(:id))

    # Counted up front, while the rows still exist — these go via the `user_interventions` cascade,
    # so `destroy_all` never reports them and a caller reading `counts` would otherwise be told a
    # purge removed nothing but sessions.
    counts = {
      user_sessions: user_sessions.count,
      answers: Answer.where(user_session_id: user_sessions.select(:id)).count,
      generated_reports: GeneratedReport.where(user_session_id: user_sessions.select(:id)).count,
      tlfb_days: Tlfb::Day.where(user_session_id: user_sessions.select(:id)).count
    }

    counts[:chart_statistics] = ChartStatistic.where(user_session_id: user_sessions.select(:id)).destroy_all.size
    counts[:sms_campaign_events] = SmsCampaignEvent.where(user_session_id: user_sessions.select(:id)).destroy_all.size
    counts[:conversations] = conversations_for(user, intervention_id).destroy_all.size
    counts[:sms_links_users] = sms_links_users_for(user, intervention_id).destroy_all.size
    counts[:user_interventions] = user_interventions.destroy_all.size

    counts
  end

  # The conversation is destroyed whole — both interlocutors and every message with it — because a
  # live-chat conversation belongs to the intervention, not to the participant, and its messages
  # reference the interlocutor with no `ON DELETE` action. A test participant's conversation has no
  # value to the navigator once the participant is gone.
  #
  # Worth stating plainly: this reaches past the participant. The cascade also takes the navigator's
  # interlocutor row and the conversation's `notifications`, which are the **navigator's** records,
  # not the participant's. That is accepted for a conversation whose only other party was a test
  # run — but it is why this query must stay intersected with the marked intervention.
  def conversations_for(user, intervention_id)
    LiveChat::Conversation
      .where(intervention_id: intervention_id)
      .where(id: LiveChat::Interlocutor.where(user_id: user.id).select(:conversation_id))
  end

  # `sms_links_users` has no association on `User`, so nothing cleans it up — and it is reachable
  # from the intervention only through `sms_links → sessions`, which is how it gets scoped.
  def sms_links_users_for(user, intervention_id)
    SmsLinksUser
      .where(user_id: user.id)
      .where(sms_link_id: SmsLink.joins(:session).where(sessions: { intervention_id: intervention_id }).select(:id))
  end

  # The shell goes only when nothing references it any more. A guest who also filled a *different*
  # researcher's "anyone with the link" intervention keeps their account — the database enforces
  # this too (`restrict_with_exception`), but relying on the raise would abort the whole purge, so
  # the condition is checked explicitly.
  def destroy_shell_or_release_marker(user)
    return release_marker(user) unless orphaned?(user)

    User.where(id: user.id, test_run: true).destroy_all.size
  end

  # Every inbound foreign key on `users` that has neither an `ON DELETE` action nor a Rails
  # `dependent:` — i.e. everything the database will refuse to let go — plus the
  # `restrict_with_exception` associations. The list comes from PART A of the cascade spike, which
  # reads it out of `pg_constraint` rather than from `schema.rb`.
  #
  # This must stay exhaustive. A missing blocker does not degrade gracefully: `orphaned?` returns
  # true, `destroy_all` raises a FK violation, `Database::Transactional` unwinds the entire purge,
  # and — because nothing about the input changed — every retry fails the same way, so the
  # participant's data is never deleted at all.
  #
  # The three out-of-scope-for-a-guest columns are checked anyway: they cost one indexed `EXISTS`
  # each, and "a guest can never be an intervention's editor" is an assumption about product
  # behaviour, not something the schema enforces.
  def orphaned?(user)
    !UserIntervention.exists?(user_id: user.id) &&
      !UserSession.exists?(user_id: user.id) &&
      !UserSession.exists?(fulfilled_by_id: user.id) &&
      !::Intervention.exists?(user_id: user.id) &&
      !::Intervention.exists?(current_editor_id: user.id) &&
      !LiveChat::Interlocutor.exists?(user_id: user.id) &&
      !SmsLinksUser.exists?(user_id: user.id)
  end

  # The marker has done its job for this intervention, and the guest's surviving data is not test
  # data. Leaving it set would make the user a permanent candidate for every later purge sweep.
  # `update_columns` deliberately skips validations and callbacks — this is bookkeeping on a record
  # the purge is finished with, not a domain update.
  def release_marker(user)
    user.update_columns(test_run: false, test_run_intervention_id: nil, purge_scheduled_at: nil) # rubocop:disable Rails/SkipsModelValidations

    0
  end

  def without_audit_trail(&block)
    PaperTrail.request(enabled: false) do
      suppress_auditing(AUDIT_SUPPRESSED_MODELS, &block)
    end
  end

  def suppress_auditing(models, &block)
    return yield if models.empty?

    head, *tail = models
    head.without_auditing { suppress_auditing(tail, &block) }
  end

  # A refusal is the quiet path — nothing is destroyed and the caller gets a Result it may not
  # inspect — so it is logged. `:unscoped_marker` in particular should never happen
  # (`V1::TestRuns::MarkGuest` writes `test_run` and `test_run_intervention_id` in one `update!`),
  # and if it ever does it means a marked participant can never be purged by any route.
  def skipped(reason)
    Rails.logger.warn("[TestParticipants::PurgeService] skipped user_id=#{user_id} reason=#{reason}")

    Result.new(purged: false, user_destroyed: false, skip_reason: reason, counts: {})
  end
end
