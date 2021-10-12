# frozen_string_literal: true

class Intervention::Csv::Harvester
  DEFAULT_VALUE = 888
  attr_reader :sessions
  attr_accessor :header, :rows, :users, :user_column

  def initialize(sessions)
    @sessions = sessions
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
    sessions.each do |session|
      session.fetch_variables.each do |question_hash|
        question_hash[:variables].each { |var| header << add_session_variable_to_question_variable(session, var) }
      end
    end

    header.flatten!
    header.unshift(:email)
    header.unshift(:user_id)
  end

  def add_session_variable_to_question_variable(session, variable)
    variable = 'phoneticName' if variable.eql?('.:name:.')

    "#{session.variable}.#{variable}"
  end

  def set_rows
    users.each_with_index do |user, row_index|
      initialize_row
      user.user_sessions.where(session_id: session_ids).each_with_index do |user_session, index|
        set_user_data(row_index, user_session) if index.zero?
        user_session.answers.each do |answer|

          set_default_value(user_session, answer, row_index)
          next if answer.skipped

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
    sessions.pluck(:id)
  end

  def initialize_row
    rows << Array.new(header.size)
  end

  def set_user_data(index, user_session)
    rows[index][0] = user_session.user_id
    rows[index][1] = user_session.user.email
  end

  def set_default_value(user_session, answer, row_index)
    return unless answer.skipped

    answer.question.csv_header_names.each do |variable|
      var_index = header.index("#{user_session.session.variable}.#{variable}")
      next if var_index.blank?

      rows[row_index][var_index] = DEFAULT_VALUE
    end
  end
end
