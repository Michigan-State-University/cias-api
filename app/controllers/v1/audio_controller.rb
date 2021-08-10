# frozen_string_literal: true

class V1::AudioController < V1Controller
  def create
    text = audio_params[:text]
    language_code = current_language_code
    voice_type = current_voice_type
    audio_url = V1::AudioService.call(text, preview: true, language_code: language_code,
                                            voice_type: voice_type).url

    render json: { url: audio_url }
  end

  private

  def audio_params
    params.require(:audio).permit(:text, :user_session_id, :google_tts_voice_id)
  end

  def current_language_code
    return UserSession.find(audio_params[:user_session_id])&.session&.google_tts_voice&.language_code if audio_params[:user_session_id].present?

    GoogleTtsVoice.find(audio_params[:google_tts_voice_id])&.language_code if audio_params[:google_tts_voice_id].present?
  end

  def current_voice_type
    return UserSession.find(audio_params[:user_session_id])&.session&.google_tts_voice&.voice_type if audio_params[:user_session_id].present?

    GoogleTtsVoice.find(audio_params[:google_tts_voice_id])&.voice_type if audio_params[:google_tts_voice_id].present?
  end
end
