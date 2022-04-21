# frozen_string_literal: true

class V1::CatMh::VoicesController < V1Controller
  def index
    authorize! :read_cat_resources, current_v1_user

    render json: serialized_response(voices_scope)
  end

  private

  def voices_scope
    CatMhLanguage.find(language_id).google_tts_voices
  end

  def language_id
    params[:language_id]
  end
end
