# frozen_string_literal: true

class V1::Google::VoicesController < V1Controller
  def index
    authorize! :index, GoogleTtsVoice

    render json: serialized_response(google_tts_voices_scope)
  end

  private

  def language_id
    params[:language_id]
  end

  def language_code
    GoogleLanguage.find(language_id)&.language_code
  end

  def google_tts_voices_scope
    GoogleTtsVoice.where('language_code LIKE ?', "#{language_code}%")
  end
end
