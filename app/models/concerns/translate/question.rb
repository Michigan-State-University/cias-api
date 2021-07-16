# frozen_string_literal: true

class Translate::Question < Translate::Base
  def execute
    source.translate_title(translator, source_language_name_short, destination_language_name_short)
    source.translate_subtitle(translator, source_language_name_short, destination_language_name_short)
    source.translate_image_description(translator, source_language_name_short, destination_language_name_short)
    V1::Translations::NarratorBlocks.call(source, translator, source_language_name_short, destination_language_name_short)
    source.translate_body(translator, source_language_name_short, destination_language_name_short)
    source.save!
  end
end
