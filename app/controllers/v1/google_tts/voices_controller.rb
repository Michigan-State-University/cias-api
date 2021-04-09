# frozen_string_literal: true

class V1::GoogleTts::VoicesController < V1Controller
  def index
    authorize! :index, GoogleTtsVoice

    render json: serialized_response(google_tts_voices_scope)
  end

  private

  def google_tts_languages_voices_service
    @google_tts_languages_voices_service ||= V1::GoogleTtsLanguagesVoicesService.new
  end

  def google_tts_voices_scope
    google_tts_languages_voices_service.google_tts_voices(language_id)
  end

  def language_id
    params[:language_id]
  end
end
