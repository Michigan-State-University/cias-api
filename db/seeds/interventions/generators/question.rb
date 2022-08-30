# frozen_string_literal: true

require_relative './/..//question_data_handler'

# rubocop:disable Rails/Output
def create_question(data_handler, question_num)
  questions = [single_q, number_q, date_q, multi_q, free_q, currency_q].freeze

  default_data = data_handler.new_table_with_default_values('questions', Question.columns_hash)

  question_group_ids = QuestionGroup.ids

  index = 0
  max_index = question_group_ids.count * question_num

  data = default_data

  question_group_ids.each do |question_group_id|
    position = 0
    question_num.times do
      question = questions.sample
      data[:type] = question.type
      data[:question_group_id] = question_group_id
      data[:settings] = question.settings
      data[:position] = position
      data[:title] = question.title
      data[:subtitle] = question.subtitle
      data[:narrator] = question.narrator
      data[:formulas] = question.formulas
      data[:body] = question.body
      data_handler.store_data(data)
      position += 1
      p "#{index += 1}/#{max_index} questions created"
    end
  end
  data_handler.save_data_to_db
  p 'Successfully added Questions to database!'
end

# rubocop:enable Rails/Output
