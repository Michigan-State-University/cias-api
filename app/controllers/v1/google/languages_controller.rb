# frozen_string_literal: true

class V1::Google::LanguagesController < V1Controller
  def index
    authorize! :index, GoogleLanguage

    render json: extended_response(language_collection)
  end

  private

  def language_collection
    GoogleLanguage.all
  end

  def extended_response(collection)
    V1::SupportedLanguageSerializer.new(collection)
  end
end
