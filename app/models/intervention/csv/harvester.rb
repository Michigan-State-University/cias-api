# frozen_string_literal: true

class Intervention::Csv::Harvester
  include DateTimeInterface
  DEFAULT_VALUE = 888
  DEFAULT_VALUE_FOR_TLFB_ANSWER = 0
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
    sessions.order(:position).each do |session|
      session.fetch_variables.each do |question_hash|
        question_hash[:variables].each { |var| header << add_session_variable_to_question_variable(session, var) }
      end

      header.concat(session_times_metadata(session))
      header.concat(quick_exit_header(session))
    end

    header.flatten!
    header.unshift(:email)
    header.unshift(:user_id)
  end

  def session_times_metadata(session)
    %W[#{session.variable}.metadata.session_start #{session.variable}.metadata.session_end #{session.variable}.metadata.session_duration]
  end

  def quick_exit_header(session)
    session.intervention.quick_exit ? %W[#{session.variable}.metadata.quick_exit] : []
  end

  def ignored_types
    %w[Question::Feedback Question::Information Question::Finish Question::ThirdParty]
  end

  def add_session_variable_to_question_variable(session, variable)
    variable = 'metadata.phonetic_name' if variable.eql?('.:name:.')

    "#{session.variable}.#{variable}"
  end

  def set_rows
    users.each_with_index do |user, row_index|
      initialize_row
      user.user_sessions.where(session_id: session_ids).each_with_index do |user_session, index|
        set_user_data(row_index, user_session) if index.zero?
        session_variable = user_session.session.variable
        user_session.answers.each do |answer|
          set_default_value(user_session, answer, row_index)
          next if answer.skipped

          answer.body_data&.each do |data|
            var_index = header.index("#{session_variable}.#{answer.csv_header_name(data)}")
            next if var_index.blank?

            var_value = answer.csv_row_value(data)
            rows[row_index][var_index] = var_value
          end
        end

        fill_by_tlfb_research(row_index, user_session)
        metadata(session_variable, user_session, row_index)
        quick_exit(session_variable, row_index, user_session)
      end
    end
  end

  def metadata(session_variable, user_session, row_index)
    session_headers_index = header.index("#{session_variable}.metadata.session_start")
    session_start = user_session.created_at
    session_end = user_session.finished_at
    unless session_end.nil?
      rows[row_index][session_headers_index + 2] = time_diff(session_start, session_end) # session duration
      rows[row_index][session_headers_index + 1] = session_end
    end
    rows[row_index][session_headers_index] = session_start
  end

  def quick_exit(session_variable, row_index, user_session)
    session_header_index = header.index("#{session_variable}.metadata.quick_exit")

    rows[row_index][session_header_index] = boolean_to_int(user_session.quick_exit) if session_header_index.present?
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

  def boolean_to_int(value)
    value ? 1 : 0
  end

  def fill_by_tlfb_research(row_index, user_session)
    session = user_session.session

    return if session.type.eql? 'Session::CatMh'

    session.question_groups.where(type: 'QuestionGroup::Tlfb').find_each do |tlfb_question_group|
      session_variable = session.variable
      days = Tlfb::Day.where(user_session_id: user_session.id, question_group_id: tlfb_question_group.id)
      days.each_with_index do |day, day_index|
        consumption_result = day.consumption_result
        next if consumption_result.blank?

        fill_by_default_value(tlfb_question_group, row_index, session_variable, day_index + 1)
        if simple_yes_or_no?(tlfb_question_group)
          fill_by_simple_question_yes_or_not(tlfb_question_group, row_index, session_variable, day_index + 1,
                                             consumption_result)
        end

        consumption_result.body['consumptions']&.each do |consumption|
          var_index = header.index("#{session_variable}.tlfb.#{consumption['variable']}_d#{day_index + 1}")
          rows[row_index][var_index] = consumption['amount'] || boolean_to_int(consumption['consumed']) if var_index.present?
        end
      end
    end
  end

  def fill_by_simple_question_yes_or_not(tlfb_question_group, row_index, session_variable, day_number, consumption_result)
    var_index = header.index("#{session_variable}.tlfb.#{tlfb_question_group.title_as_variable}_d#{day_number}")
    rows[row_index][var_index] = boolean_to_int(consumption_result.body['substances_consumed'])
  end

  def simple_yes_or_no?(tlfb_question_group)
    question_body = tlfb_question_group.questions.find_by(type: 'Question::TlfbQuestion').body

    question_body.dig('data', 0, 'payload', 'substance_groups').blank? && question_body.dig('data', 0, 'payload', 'substances').blank?
  end

  def boolean_to_int(value)
    value ? 1 : 0
  end

  def fill_by_default_value(tlfb_group, row_index, session_variable, day_number)
    tlfb_question = tlfb_group.questions.find_by(type: 'Question::TlfbQuestion')

    if tlfb_question.body_data.first.dig('payload', 'substances_with_group')
      fill_by_default_for_substance_groups(tlfb_question.body_data.first.dig('payload', 'substance_groups'), row_index, session_variable, day_number)
    else
      fill_by_default_value_for_substances_in_day(tlfb_question.body_data.first.dig('payload', 'substances'), row_index, session_variable, day_number)
    end
  end

  def fill_by_default_for_substance_groups(collection_of_substance_groups, row_index, session_variable, day_number)
    collection_of_substance_groups.each do |substance_group|
      fill_by_default_value_for_substances_in_day(substance_group['substances'], row_index, session_variable, day_number)
    end
  end

  def fill_by_default_value_for_substances_in_day(collection_of_substances, row_index, session_variable, day_number)
    collection_of_substances.each do |substance|
      var_index = header.index("#{session_variable}.tlfb.#{substance['variable']}_d#{day_number}")
      next if var_index.blank?

      rows[row_index][var_index] = DEFAULT_VALUE_FOR_TLFB_ANSWER
    end
  end
end
