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
      header.insert(index, add_session_variable_to_question_variables(question))
    end
    header.flatten!
    header.unshift(:email)
    header.unshift(:user_id)
  end

  def add_session_variable_to_question_variables(question)
    session_variable = question.question_group.session.variable
    question.csv_header_names.map { |question_variable| "#{session_variable}.#{question_variable}" }
  end

  def set_rows
    users.each_with_index do |user, row_index|
      initialize_row

      user.user_sessions.where(session_id: session_ids).each_with_index do |user_session, index|
        set_user_data(row_index, user_session) if index.zero?
        user_session.answers.each do |answer|
          answer.body_data&.each do |data|
            var_index = header.index("#{user_session.session.variable}.#{answer.csv_header_name(data)}")
            next if var_index.blank?

            var_value = answer.csv_row_value(data)
            rows[row_index][var_index] = var_value
          end
        end
      end
    end
  end

  def users
    user_ids = UserSession.where(session_id: session_ids).pluck(:user_id)
    User.where(id: user_ids).includes(:user_sessions)
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
