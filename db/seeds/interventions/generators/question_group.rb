# frozen_string_literal: true

# rubocop:disable Rails/Output
def create_question_group(data_handler, question_group_num)
  default_data = data_handler.new_table_with_default_values('question_groups', QuestionGroup.columns_hash)

  session_ids = Session.ids

  index = 0
  max_index = session_ids.count * question_group_num

  data = default_data

  session_ids.each do |session_id|
    position_counter = 0
    question_group_num.times do
      data[:session_id] = session_id
      data[:title] = "Group #{position_counter}"
      data[:position] = position_counter
      data[:type] = 'QuestionGroup::Plain'
      data[:questions_count] = question_group_num
      data_handler.store_data(data)
      position_counter += 1

      p "#{index += 1}/#{max_index} question groups created"
    end
  end
  data_handler.save_data_to_db
  p 'Successfully added QuestionGroups to database!'
end

# rubocop:enable Rails/Output
