# frozen_string_literal: true

class V1::CatMh::LanguagesController < V1Controller
  def index
    authorize! :read_cat_resources, current_v1_user

    render json: languages_response
  end

  private

  def languages_response
    V1::CatMh::LanguageSerializer.new(CatMhLanguage.all).serializable_hash.to_json
  end
end
