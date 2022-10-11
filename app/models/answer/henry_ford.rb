# frozen_string_literal: true

class Answer::HenryFord < Answer
  def csv_header_name(data)
    "hfs.#{data['var']}"
  end
end
