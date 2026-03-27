# frozen_string_literal: true

module UserSession::ClassicBehavior
  extend ActiveSupport::Concern

  included do
    belongs_to :name_audio, class_name: 'Audio', optional: true

    before_destroy :decrement_audio_usage, :cancel_timeout_job

    delegate :first_question, :autofinish_enabled, :autofinish_delay, :questions, to: :session
  end

  def on_answer
    cancel_timeout_job
    return unless autofinish_enabled

    if any_question_run_timeout?
      set_timeout_job if timeout_job_id.present? || last_answer&.question&.settings&.dig('start_autofinish_timer')
    else
      set_timeout_job
    end
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

  def set_timeout_job
    timeout_job = UserSessionTimeoutJob.set(wait: autofinish_delay.minutes).perform_later(id)
    cancel_timeout_job
    update(last_answer_at: DateTime.current, timeout_job_id: timeout_job.provider_job_id)
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
