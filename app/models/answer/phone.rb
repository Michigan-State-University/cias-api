# frozen_string_literal: true

class Answer::Phone < Answer
  def csv_row_value(data)
    if data['value']['time_ranges'].present?
      "{provided_number => #{data['value']['prefix']}#{data['value']['number']}, selected_time_ranges => #{data['value']['time_ranges']}, timezone => #{data['value']['timezone']}}"
    else
      "{provided_number => #{data['value']['prefix']}#{data['value']['number']}}"
    end
  end
end
