# frozen_string_literal: true

class Intervention::Csv::Harvester
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
    set_headers
    set_rows
    self
  end

  private

  def set_headers
    questions.each_with_index do |question, index|
      header.insert(index, question.csv_header_names)
    end
    header.flatten!
    header.unshift(:email)
    header.unshift(:user_id)
  end

  def set_rows
    user_sessions.each_with_index do |user_session, row_index|
      initialize_row
      set_user_data(row_index, user_session)

      user_session.answers.each do |answer|
        answer.body_data&.each do |data|
          var_index = header.index(answer.csv_header_name(data))
          next if var_index.blank?

          var_value = answer.csv_row_value(data)
          rows[row_index][var_index] = var_value
        end
      end
    end
  end

  def user_sessions
    UserSession.where(session_id: session_ids)
  end

  def session_ids
    questions.select('question_groups.session_id')
  end

  def initialize_row
    rows << Array.new(header.size)
  end

  def set_user_data(index, user_session)
    rows[index][0] = user_session.user_id
    rows[index][1] = user_session.user.email
  end
end
