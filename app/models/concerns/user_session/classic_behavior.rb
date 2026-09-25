# frozen_string_literal: true

module UserSession::ClassicBehavior
  extend ActiveSupport::Concern

  # How long a participant may stay inactive before a session that passed the
  # "Fire report if get this far" threshold is closed and its reports generated.
  # Only used when the researcher left autofinish off - otherwise autofinish_delay wins.
  INACTIVITY_TIMEOUT_DELAY = ENV.fetch('INACTIVITY_TIMEOUT_DELAY_MINUTES', 30).to_i.minutes

  included do
    belongs_to :name_audio, class_name: 'Audio', optional: true

    before_destroy :decrement_audio_usage, :cancel_timeout_job

    delegate :first_question, :autofinish_enabled, :autofinish_delay, :questions, to: :session
  end

  def on_answer
    cancel_timeout_job

    if autofinish_enabled
      if any_question_run_timeout?
        set_timeout_job if threshold_passed?
      else
        set_timeout_job
      end
    elsif any_question_run_timeout? && threshold_passed?
      set_timeout_job(wait: INACTIVITY_TIMEOUT_DELAY, reason: 'inactivity_timeout')
    end
  end

  # True once the participant has answered a screen flagged with "Fire report if get this far".
  # Every later answer keeps the timeout armed, so the countdown slides instead of being dropped.
  def threshold_passed?
    answers.confirmed.joins(:question)
           .where("questions.settings @> '{\"start_autofinish_timer\": true}'")
           .exists?
  end

  def inactivity_elapsed?
    inactivity_deadline <= Time.current
  end

  # Gives the session the rest of its window back when a job fires early - a stale one
  # whose cancellation did not stick, or one enqueued before a later answer slid the deadline.
  def rearm_inactivity_timeout
    arm_timeout_job(wait: inactivity_deadline - Time.current, reason: 'inactivity_timeout')
  end

  def inactivity_deadline
    (last_answer_at || created_at) + INACTIVITY_TIMEOUT_DELAY
  end

  def cancel_timeout_job
    return if timeout_job_id.nil?

    UserSessionTimeoutJob.cancel_by(provider_job_id: timeout_job_id)

    update(timeout_job_id: nil)
  end

  def last_answer
    answers.confirmed.unscope(:order).order(:updated_at).last
  end

  private

  def any_question_run_timeout?
    questions.where("settings @> '{\"start_autofinish_timer\": true}'").any?
  end

  def set_timeout_job(wait: autofinish_delay.minutes, reason: 'completed')
    arm_timeout_job(wait: wait, reason: reason, attrs: { last_answer_at: DateTime.current })
  end

  def arm_timeout_job(wait:, reason:, attrs: {})
    timeout_job = UserSessionTimeoutJob.set(wait: wait).perform_later(id, reason)
    cancel_timeout_job
    update(attrs.merge(timeout_job_id: timeout_job.provider_job_id))
  end

  def decrement_audio_usage
    return if name_audio.nil?

    name_audio.decrement(:usage_counter)
    name_audio.save!
  end

  def delete_alternative_answers
    answers.where(draft: true, alternative_branch: true).destroy_all
  end
end
