# frozen_string_literal: true

class V1::Translations::Intervention
  attr_reader :source_intervention, :destination_language_id, :destination_tts_voice_id

  def self.call(intervention, destination_language_id, destination_tts_voice_id)
    new(intervention, destination_language_id, destination_tts_voice_id).call
  end

  def initialize(intervention, destination_language_id, destination_tts_voice_id)
    @source_intervention = intervention
    @destination_language_id = destination_language_id
    @destination_tts_voice_id = destination_tts_voice_id
  end

  def call
    return if destination_language_id.nil?

    cloned_resource = source_intervention.clone
    translator = V1::Google::TranslationService.new
    cloned_resource.translate(translator, source_language_name_short, destination_language_name_short)
    change_language(cloned_resource)
    destination_tts_voice_id ? change_tts_in_sessions(cloned_resource) : clear_speech_blocks(cloned_resource)
    cloned_resource
  end

  private

  def destination_language_name_short
    GoogleLanguage.find(destination_language_id)&.language_code
  end

  def source_language_name_short
    source_intervention.google_language.language_code
  end

  def change_language(intervention)
    intervention.update!(google_language_id: destination_language_id)
  end

  def change_tts_in_sessions(intervention)
    intervention.sessions.each { |session| session.update!(google_tts_voice_id: destination_tts_voice_id) }
  end

  def clear_speech_blocks(intervention)
    intervention.sessions.each(&:clear_speech_blocks)
  end
end
