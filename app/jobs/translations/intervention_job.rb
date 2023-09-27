# frozen_string_literal: true

class Translations::InterventionJob < ApplicationJob
  queue_as :translations
  def perform(intervention_id, destination_language_id, destination_google_tts_voice_id, current_user)
    intervention = find_intervention(intervention_id, current_user)
    translated_intervention = V1::Translations::Intervention.call(intervention, destination_language_id, destination_google_tts_voice_id)
    Intervention.reset_counters(translated_intervention.id, :sessions)
    translated_intervention.update!(is_hidden: false)

    return unless current_user.email_notification

    TranslationMailer.with(locale: intervention.language_code).confirmation(current_user, intervention, translated_intervention).deliver_now
  rescue StandardError => e
    logger.error "TRANSLATION ERROR LOG #{e}"
    translated_intervention&.sessions&.destroy_all
    translated_intervention&.destroy
    return unless current_user.email_notification

    TranslationMailer.with(locale: intervention.language_code).error(current_user).deliver_now
  end

  private

  def find_intervention(id, current_user)
    Intervention.accessible_by(current_user.ability).find(id)
  end
end
