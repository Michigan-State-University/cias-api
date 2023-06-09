# frozen_string_literal: true

class Answer::Name < Answer
  def on_answer
    text = body_data&.first&.dig('value').presence&.dig('phonetic_name') || ''
    user_session.name_audio = V1::AudioService.call(text,
                                                    language_code: question.session.google_tts_voice.language_code,
                                                    voice_type: question.session.google_tts_voice.voice_type)
    user_session.save!
  end

  def csv_header_name(_data)
    'metadata.phonetic_name'
  end
end
