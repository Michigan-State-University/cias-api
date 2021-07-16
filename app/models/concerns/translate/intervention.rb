# frozen_string_literal: true

class Translate::Intervention < Translate::Base
  def execute
    source.translation_prefix(destination_language_name_short)
    source.translate_sessions(translator, source_language_name_short, destination_language_name_short)
    source.translate_logo_description(translator, source_language_name_short, destination_language_name_short)
  end
end
