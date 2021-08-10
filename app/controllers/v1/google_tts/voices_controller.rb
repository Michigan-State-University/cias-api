# frozen_string_literal: true

class V1::GoogleTts::VoicesController < V1Controller
  def index
    authorize! :index, GoogleTtsVoice

    render json: serialized_response(google_tts_voices_scope)
  end

  private

  def google_tts_language_scope
    GoogleTtsLanguage.includes(:google_tts_voices)
  end

  def google_tts_voices_scope
    google_tts_language_scope.find(language_id).google_tts_voices
  end

  def language_id
    params[:language_id]
  end
end
