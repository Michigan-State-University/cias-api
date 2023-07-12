# frozen_string_literal: true

module TranslationAuxiliaryMethods
  extend ActiveSupport::Concern

  included do
    def translate_attribute(attribute_name, attribute_value, translator, source_language_name_short, destination_language_name_short)
      original_text[attribute_name] = attribute_value
      new_value = translator.translate(attribute_value, source_language_name_short, destination_language_name_short)

      update!({ attribute_name => new_value })
    end
  end
end
