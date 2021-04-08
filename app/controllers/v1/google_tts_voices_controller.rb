# frozen_string_literal: true

class V1::GoogleTtsVoicesController < V1Controller
  def index
    authorize! :index, GoogleTtsVoice

    render json: serialized_response(google_tts_voices_scope)
  end

  private

  def google_tts_languages_voices_service
    @google_tts_languages_voices_service ||= V1::GoogleTtsLanguagesVoicesService.new
  end

  def google_tts_voices_scope
    google_tts_languages_voices_service.google_tts_voices(google_tts_language_id)
  end

  def google_tts_language_id
    params[:google_tts_language_id]
  end
end
