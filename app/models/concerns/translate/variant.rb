class Translate::Variant < Translate::Base
  def execute
    source.translate_title(translator, source_language_name_short, destination_language_name_short)
    source.translate_content(translator, source_language_name_short, destination_language_name_short)
  end
end
