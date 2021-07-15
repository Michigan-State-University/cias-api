# frozen_string_literal: true

class Translate::Session < Translate::Base
  def execute
    expanded_translator = V1::Translations::VariableExclusiveTranslationService.new(translator)

    source.translate_questions(translator, source_language_name_short, destination_language_name_short)
    source.translate_sms_plans(expanded_translator, source_language_name_short, destination_language_name_short)
    source.translate_report_templates(expanded_translator, source_language_name_short, destination_language_name_short)
  end
end
