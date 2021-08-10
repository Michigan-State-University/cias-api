# frozen_string_literal: true

class V1::GoogleTts::LanguagesController < V1Controller
  def index
    authorize! :index, GoogleTtsLanguage

    render json: serialized_response(google_tts_language_scope)
  end

  private

  def google_tts_language_scope
    GoogleTtsLanguage.all
  end
end
