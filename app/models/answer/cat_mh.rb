# frozen_string_literal: true

class Answer::CatMh < Answer
  def csv_header_name(data)
    data['var'].tr('/', '')
  end
end
