# frozen_string_literal: true

class Answer::Name < Answer
  def on_answer
    text = body_data.first.dig('value', 'phoneticName')
    user_session.name_audio = V1::AudioService.new.create(text)
    user_session.save!
  end
end
