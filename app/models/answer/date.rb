# frozen_string_literal: true

class Answer::Date < Answer
  def csv_row_value(data)
    value = data['value']
    return value if value.blank?

    ::Date.parse(value).iso8601
  rescue ::Date::Error
    value
  end
end
