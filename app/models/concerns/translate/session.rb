# frozen_string_literal: true

class Translate::Session < Translate::Base
  def execute
    source.translate_question_groups(translator, source_language_name_short, destination_language_name_short)
    # source.translate_sms_plans(translator, source_language_name_short, destination_language_name_short)
    source.translate_report_templates(translator, source_language_name_short, destination_language_name_short)
  end
end
