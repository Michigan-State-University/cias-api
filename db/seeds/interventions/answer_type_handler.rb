def answer_type_for(question_type)
  case question_type
  when 'Single'
    return :answer_single
  when 'Number'
    return :answer_number
  when 'Date'
    return :answer_date
  when 'Multiple'
    return :answer_multiple
  when 'FreeResponse'
    return :answer_free_response
  when 'Currency'
    return :answer_currency
  else
    nil
  end
end
