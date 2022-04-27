# frozen_string_literal: true

require 'google/cloud/translate/v2'

class V1::Google::TranslationService
  def translate(text, source_language_name_short, destination_language_name_short)
    return text if text.blank?

    client.translate(text, from: source_language_name_short, to: destination_language_name_short).text
  end

  private

  def client
    p "TRANSLATION ENV TEST #{ENV['WEB_URL']}"
    @client ||= Google::Cloud::Translate::V2.new(credentials: credentials)
  end

  def credentials
    if Rails.env.development?
      Oj.load_file(ENV['GOOGLE_APPLICATION_CREDENTIALS'])
    else
      Oj.load(ENV['GOOGLE_APPLICATION_CREDENTIALS'])
    end
  rescue Oj::ParseError
    ENV['GOOGLE_APPLICATION_CREDENTIALS']
  end
end
