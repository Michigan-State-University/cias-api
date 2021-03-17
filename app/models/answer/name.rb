# frozen_string_literal: true

class Answer::Name < Answer
  def on_answer
    text = body_data.first.dig('value', 'phonetic_name')
    user_session.name_audio = V1::AudioService.new(text).execute
    user_session.save!
  end

  def csv_header_name(_data)
    'phoneticName'
  end
end
