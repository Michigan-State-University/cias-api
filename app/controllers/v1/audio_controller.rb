# frozen_string_literal: true

class V1::AudioController < V1Controller
  def create
    audio_url = V1::AudioService.call(text, preview: true, language_code: current_language_code, voice_type: current_voice_type).url

    render json: { url: audio_url }
  end

  def recreate
    authorize! :recreate_audio, Audio

    Audio::RecreateService.perform_later

    render status: :ok
  end

  def regenerate
    V1::Audio::Regenerate.call(question_id, block_index, audio_index,reflection_index,
                               current_language_code, current_voice_type)
  end


  private

  def current_language_code
    return UserSession.find(user_session_id)&.session&.google_tts_voice&.language_code if user_session_id.present?

    GoogleTtsVoice.find(google_tts_voice_id)&.language_code if google_tts_voice_id.present?
  end

  def current_voice_type
    return UserSession.find(user_session_id)&.session&.google_tts_voice&.voice_type if user_session_id.present?

    GoogleTtsVoice.find(google_tts_voice_id)&.voice_type if google_tts_voice_id.present?
  end

  def audio_params
    params.require(:audio).permit(:text, :user_session_id, :google_tts_voice_id)
  end

  def regenerate_audio_params
    params.require(:audio).permit(:question_id, :user_session_id, :block_index, :reflection_index, :audio_index)
  end

  def text
    audio_params[:text]
  end

  def user_session_id
    audio_params[:user_session_id]
  end

  def google_tts_voice_id
    audio_params[:google_tts_voice_id]
  end

  def block_index
    regenerate_audio_params[:block_index]
  end

  def reflection_index
    regenerate_audio_params[:reflection_index]
  end

  def audio_index
    regenerate_audio_params[:audio_index]
  end
end
