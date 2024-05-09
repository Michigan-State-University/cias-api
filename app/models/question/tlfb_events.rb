# frozen_string_literal: true

class Question::TlfbEvents < Question::Tlfb
  attribute :settings, :json, default: -> { { start_autofinish_timer: false } }

  validates :accepted_answers, absence: true

  def translate_body(translator, source_language_name_short, destination_language_name_short)
    body['data'].each do |record|
      record['original_text'] = {}

      %w[screen_title screen_question].each do |event_data|
        record['original_text'][event_data] = record['payload'][event_data]
        record['payload'][event_data] = translator.translate(record['payload'][event_data], source_language_name_short, destination_language_name_short)
      end
    end
  end

  def first_question?
    first_question = session.first_question
    first_question.type.eql?('Question::TlfbConfig') && first_question.question_group.id == question_group.id
  end
end
