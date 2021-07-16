# frozen_string_literal: true

class V1::Translations::TranslationsController < V1Controller
  def translate_intervention
    authorize! :translate, Intervention

    intervention = find_intervention(intervention_id)
    translated_intervention = V1::Translations::Intervention.call(intervention, destination_language_id, destination_tts_language_id)
    render json: serialized_response(translated_intervention,'Intervention'), status: :created
  end

  private

  def intervention_id
    params.require(:id)
  end

  def destination_language_id
    params.require(:dest_language_id)
  end

  def destination_tts_language_id
    params.permit(:dest_tts_language_id)
  end

  def find_intervention(id)
    Intervention.accessible_by(current_ability).find(id)
  end
end
