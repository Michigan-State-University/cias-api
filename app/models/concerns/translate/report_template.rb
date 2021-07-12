class Translate::ReportTemplate < Translate::Base
  def execute
    source.translate_summary(translator, source_language_name_short, destination_language_name_short)
    source.translate_name(translator, source_language_name_short, destination_language_name_short)
    source.translate_section_variants(translator, source_language_name_short, destination_language_name_short)
  end
end
