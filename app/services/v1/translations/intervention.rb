# frozen_string_literal: true

class V1::Translations::Intervention
  attr_reader :source_intervention, :destination_language_id, :destination_tts_language_id

  def self.call(intervention, destination_tts_language_id)
    new(intervention, destination_tts_language_id).call
  end

  def initialize(intervention, destination_tts_language_id)
    @source_intervention = intervention
    @destination_tts_language_id = destination_tts_language_id
  end

  def call
    cloned_resource = source_intervention.clone
    translator = V1::Google::TranslationService.new
    cloned_resource.translate(translator, source_language_name_short, destination_language_name_short)
  end

  private

  def destination_language_name_short
    GoogleLanguage.find(destination_tts_language_id)&.language_code
  end

  def source_language_name_short
    source_intervention.google_language.language_code
  end
end
