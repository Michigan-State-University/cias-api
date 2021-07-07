# frozen_string_literal: true

module Translate
  include MetaOperations

  def translate(translator, source_language_name_short, destination_language_name_short)
    "Translate::#{de_constantize_modulize_name.classify}".
      safe_constantize.new(self, translator, source_language_name_short, destination_language_name_short).execute
  end
end
