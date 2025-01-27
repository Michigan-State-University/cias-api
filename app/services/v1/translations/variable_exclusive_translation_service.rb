# frozen_string_literal: true

class V1::Translations::VariableExclusiveTranslationService
  def initialize(translation_service)
    @translator = translation_service
  end

  def translate(text, src_language_name_short, dest_language_name_short)
    return text if text.blank?

    variable_names = extract_variable_names(text)
    text_for_translation = text.gsub(VARIABLE_NAME_PATTERN, VARIABLE_NAME_PLACEHOLDER_TOKEN)
    new_text = @translator.translate(text_for_translation, src_language_name_short, dest_language_name_short).to_s
    insert_variable_names(new_text, variable_names)
  end

  private

  VARIABLE_NAME_PLACEHOLDER_TOKEN = '%%%'
  VARIABLE_NAME_PATTERN = /\.:[a-zA-Z0-9_]*?:\./

  def extract_variable_names(input_string)
    input_string.scan(VARIABLE_NAME_PATTERN)
  end

  def insert_variable_names(input_string, variable_names)
    pattern = Regexp.escape(VARIABLE_NAME_PLACEHOLDER_TOKEN)
    variable_names.reduce(input_string) { |original, var_name| original.sub(pattern, var_name) }
  end
end
