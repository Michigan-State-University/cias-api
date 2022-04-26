# frozen_string_literal: true

class Translations::InterventionJob < ApplicationJob
  queue_as :translations
  def perform(intervention_id, destination_language_id, destination_google_tts_voice_id, current_user)
    intervention = find_intervention(intervention_id, current_user)
    translated_intervention = V1::Translations::Intervention.call(intervention, destination_language_id, destination_google_tts_voice_id)

    return unless current_user.email_notification

    TranslationMailer.confirmation(current_user, intervention, translated_intervention).deliver_now
  rescue StandardError => e
    logger.error "Translation error log #{e}"
    return unless current_user.email_notification

    TranslationMailer.error(current_user).deliver_now
  end

  private

  def find_intervention(id, current_user)
    Intervention.accessible_by(current_user.ability).find(id)
  end
end
