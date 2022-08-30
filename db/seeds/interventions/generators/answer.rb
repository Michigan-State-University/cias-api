# frozen_string_literal: true

# rubocop:disable Rails/Output
def create_answers(data_handler, max_per_question)
  default_data = data_handler.new_table_with_default_values('answers', Answer.columns_hash)

  user_sessions = UserSession.all

  index = 0
  max_index = Question.count * max_per_question

  data = {
    body_ciphertext: nil
  }
  data = default_data.merge(data)
  Question.find_each do |question|
    user_sessions.limit(max_per_question).ids.each do |user_session_id|
      data[:type] = "Answer::#{question.type.demodulize}"
      data[:question_id] = question.id
      data[:user_session_id] = user_session_id
      data[:next_session_id] = nil
      data_handler.store_data(data)

      p "#{index += 1}/#{max_index} answers created"
    end
  end
  data_handler.save_data_to_db
  p 'Successfully added Answers to database!'
end

# rubocop:enable Rails/Output
