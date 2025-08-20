# frozen_string_literal: true

require 'google/cloud/translate/v2'
require 'nokogiri'

class V1::Google::TranslationService
  def translate(text, source_language_name_short, destination_language_name_short)
    return text if text.blank?

    removed_images_result = remove_image_tags(text)
    translated_text = client.translate(removed_images_result[:text], from: source_language_name_short, to: destination_language_name_short).text
    retrieve_image_tags(translated_text, removed_images_result[:placeholders])
  end

  private

  def client
    @client ||= Google::Cloud::Translate::V2.new(credentials: credentials)
  end

  def remove_image_tags(text)
    placeholders = {}
    doc = Nokogiri::HTML.fragment(text)

    doc.css('img[src^="data:image"]').each_with_index do |img, index|
      placeholder = "<imgplaceholder#{index}>"

      placeholders[placeholder] = img.to_html
      img.replace(placeholder)
    end

    { text: doc.to_html, placeholders: placeholders }
  end

  def retrieve_image_tags(text, placeholders)
    placeholders.each do |key, value|
      text.gsub!(key, value)
    end

    text
  end

  def credentials
    if Rails.env.development?
      Oj.load_file(ENV.fetch('GOOGLE_APPLICATION_CREDENTIALS', nil))
    else
      Oj.load(ENV.fetch('GOOGLE_APPLICATION_CREDENTIALS', nil))
    end
  rescue Oj::ParseError, JSON::ParserError
    ENV.fetch('GOOGLE_APPLICATION_CREDENTIALS', nil)
  end
end
