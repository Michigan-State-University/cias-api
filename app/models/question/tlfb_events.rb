# frozen_string_literal: true

class Question::TlfbEvents < Question::Tlfb
  def translate_body(translator, source_language_name_short, destination_language_name_short)
    body['data'].each do |record|
      record['original_text'] = {}

      %w[screen_title screen_question].each do |event_data|
        record['original_text'][event_data] = record['payload'][event_data]
        record['payload'][event_data] = translator.translate(record['payload'][event_data], source_language_name_short, destination_language_name_short)
      end
    end
  end
end
