# frozen_string_literal: true

module Intervention::TranslationAuxiliaryMethods
  extend ActiveSupport::Concern

  included do
    def translation_prefix(destination_language_name_short)
      update!(name: "(#{destination_language_name_short.upcase}) #{name}")
    end

    def translate_additional_text(translator, source_language_name_short, destination_language_name_short)
      original_text['additional_text'] = additional_text
      new_additional_text = translator.translate(additional_text, source_language_name_short, destination_language_name_short)

      update!(additional_text: new_additional_text)
    end

    def translate_sessions(translator, source_language_name_short, destination_language_name_short)
      sessions.each do |session|
        session.translate(translator, source_language_name_short, destination_language_name_short)
      end
    end
  end
end
