# frozen_string_literal: true

class Answer::Phone < Answer
  def csv_row_value(data)
    "#{data['value']['prefix']}#{data['value']['number']}"
  end
end
