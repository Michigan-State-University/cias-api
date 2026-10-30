# frozen_string_literal: true

class V1::AudioController < V1Controller
  def create
    audio_url =
      V1::AudioService.call(
        audio_params[:text],
        preview: true,
        language_code: tts_voice&.language_code,
        voice_type: tts_voice&.voice_type
      ).url

    render json: { url: audio_url }
  end

  def recreate
    authorize! :recreate_audio, Audio

    Audio::RecreateService.perform_later

    render status: :ok
  end

  def regenerate
    V1::Audio::Regenerate.call(
      audio_params,
      tts_voice&.language_code,
      tts_voice&.voice_type
    )

    render status: :ok
  end

  private

  def tts_voice
    @tts_voice ||= if audio_params[:user_session_id].present?
                     UserSession.find(audio_params[:user_session_id])&.session&.google_tts_voice
                   elsif audio_params[:session_id].present?
                     Session.find(audio_params[:session_id])&.google_tts_voice
                   elsif audio_params[:google_tts_voice_id].present?
                     GoogleTtsVoice.find(audio_params[:google_tts_voice_id])
                   end
  end

  def audio_params
    @audio_params ||= params.expect(
      audio: %i[text user_session_id session_id google_tts_voice_id question_id block_index reflection_index audio_index]
    )
  end
end
