# frozen_string_literal: true

class V1::Translations::TranslationsController < V1Controller
  around_action :with_locale, only: :translate_intervention

  def translate_intervention
    authorize! :translate, Intervention

    Translations::InterventionJob.perform_later(intervention_id, destination_language_id, destination_google_tts_voice_id, current_v1_user)
    render status: :ok
  end

  private

  def intervention_id
    params.require(:id)
  end

  def destination_language_id
    params.require(:dest_language_id)
  end

  def destination_google_tts_voice_id
    params.permit(:destination_google_tts_voice_id)[:destination_google_tts_voice_id]
  end

  def locale
    Intervention.find(intervention_id)&.language_code
  end
end
