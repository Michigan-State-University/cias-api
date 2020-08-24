# frozen_string_literal: true

class Problem::Csv::Harvester
  attr_reader :questions
  attr_accessor :header, :rows, :users, :user_column

  def initialize(questions)
    @questions = questions
    @header = []
    @rows = []
    @users = {}
    @user_column = []
  end

  def collect
    processing
    post_processing
    self
  end

  private

  def find_or_add_row(answer, index)
    locate = user_column.index(answer.user_id)
    if locate.nil?
      rows.insert(-1, [])
      user_column.insert(-1, answer.user_id)
      users[answer.user_id] = { id: answer.user_id, email: answer.user.email }
      -1
    else
      rows[locate].insert(index, [])
      locate
    end
  end

  def processing
    questions.each_with_index do |question, index|
      header.insert(index, question.harvest_body_variables)
      question.answers&.each do |answer|
        row_index = find_or_add_row(answer, index)
        answer.body_data&.each do |data|
          rows[row_index][index] = Array.new(header[index].size)
          find_result = header[index].index(data['var'])
          rows[row_index][index][find_result.to_i] = data['value']
        end
      end
    end
  end

  def post_processing
    rows.each(&:flatten!)
    user_column.each_with_index do |user_id, index|
      rows[index].unshift(users[user_id][:email])
      rows[index].unshift(users[user_id][:id])
    end
    header.unshift(:email)
    header.unshift(:user_id)
    header.flatten!
  end
end
