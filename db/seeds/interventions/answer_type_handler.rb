# frozen_string_literal: true

def answer_type_for(question_type)
  case question_type
  when 'Single'
    :answer_single
  when 'Number'
    :answer_number
  when 'Date'
    :answer_date
  when 'Multiple'
    :answer_multiple
  when 'FreeResponse'
    :answer_free_response
  when 'Currency'
    :answer_currency
  else
    :answer
  end
end
