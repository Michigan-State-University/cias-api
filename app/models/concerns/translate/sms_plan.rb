class Translate::SmsPlan < Translate::Base
  def execute
    source.translate_no_formula_text(translator, source_language_name_short, destination_language_name_short)
  end
end
