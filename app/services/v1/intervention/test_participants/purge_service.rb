# frozen_string_literal: true

class V1::Intervention::TestParticipants::PurgeService
  prepend Database::Transactional

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
    # Row lock and re-read: a participant un-marked since scheduling must survive, and two purges of one user must not interleave.
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

  def log_purge(purged_user_id, intervention_id, marked_by_id, result)
    Rails.logger.warn(
      '[TestParticipants::PurgeService] purged ' \
      "user_id=#{purged_user_id} intervention_id=#{intervention_id} marked_by_id=#{marked_by_id} " \
      "user_destroyed=#{result.user_destroyed?} counts=#{result.counts}"
    )
  end

  def destroy_scoped_data(user, intervention_id)
    user_interventions = UserIntervention.where(user_id: user.id, intervention_id: intervention_id)
    user_sessions = UserSession.where(user_intervention_id: user_interventions.select(:id))

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

  def conversations_for(user, intervention_id)
    LiveChat::Conversation
      .where(intervention_id: intervention_id)
      .where(id: LiveChat::Interlocutor.where(user_id: user.id).select(:conversation_id))
  end

  def sms_links_users_for(user, intervention_id)
    SmsLinksUser
      .where(user_id: user.id)
      .where(sms_link_id: SmsLink.joins(:session).where(sessions: { intervention_id: intervention_id }).select(:id))
  end

  def destroy_shell_or_release_marker(user)
    return release_marker(user) unless orphaned?(user)

    User.where(id: user.id, test_run: true).destroy_all.size
  end

  # Must stay exhaustive: a missing blocker makes `destroy_all` raise, unwinds the purge, and every retry fails identically — the data never goes.
  def orphaned?(user)
    !UserIntervention.exists?(user_id: user.id) &&
      !UserSession.exists?(user_id: user.id) &&
      !UserSession.exists?(fulfilled_by_id: user.id) &&
      !::Intervention.exists?(user_id: user.id) &&
      !::Intervention.exists?(current_editor_id: user.id) &&
      !LiveChat::Interlocutor.exists?(user_id: user.id) &&
      !SmsLinksUser.exists?(user_id: user.id)
  end

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

  def skipped(reason)
    Rails.logger.warn("[TestParticipants::PurgeService] skipped user_id=#{user_id} reason=#{reason}")

    Result.new(purged: false, user_destroyed: false, skip_reason: reason, counts: {})
  end
end
