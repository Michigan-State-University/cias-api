# frozen_string_literal: true

class V1::GoogleTtsLanguagesController < V1Controller
  def index
    authorize! :index, GoogleTtsLanguage

    render json: serialized_response(google_tts_languages_scope)
  end

  private

  def google_tts_languages_voices_service
    @google_tts_languages_voices_service ||= V1::GoogleTtsLanguagesVoicesService.new
  end

  def google_tts_languages_scope
    google_tts_languages_voices_service.google_tts_languages
  end
end
