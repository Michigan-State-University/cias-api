# frozen_string_literal: true

class Intervention::Csv::Harvester
  include Intervention::Csv::Tlfb
  include DateTimeInterface
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
    sessions.order(:position).each do |session|
      number_of_attempts(session).times do |index|
        session.fetch_variables.each do |question_hash|
          question_hash[:variables].each do |var|
            header << add_session_variable_to_question_variable(session, var, index, multiple_fill_indicator_for(session))
          end
        end

        header.concat(session_metadata(session, index, multiple_fill_indicator_for(session)))
        header.concat(quick_exit_header(session, index, multiple_fill_indicator_for(session)))
      end
    end

    header.unshift(hf_headers(sessions))
    header.unshift(predefined_user_headers(sessions))
    header.flatten!
    header.unshift(:email)
    header.unshift(:user_id)
  end

  def session_metadata(session, index, multiple_fill)
    [column_name(multiple_fill, session, 'metadata.session_start', index + 1), column_name(multiple_fill, session, 'metadata.session_end', index + 1),
     column_name(multiple_fill, session, 'metadata.session_duration', index + 1)]
  end

  def quick_exit_header(session, index, multiple_fill)
    return [] unless session.intervention.quick_exit

    [column_name(multiple_fill, session, 'metadata.quick_exit', index + 1)]
  end

  def ignored_types
    %w[Question::Feedback Question::Information Question::Finish Question::ThirdParty Question::SmsInformation]
  end

  def add_session_variable_to_question_variable(session, variable, index, multiple_fill)
    variable = 'metadata.phonetic_name' if variable.eql?('.:name:.')

    column_name(multiple_fill, session, variable, index + 1)
  end

  def set_rows
    grouped_and_sorted_user_sessions.each_with_index do |grouped_user_sessions, row_index|
      initialize_row
      set_user_data(row_index, grouped_user_sessions.second.first)
      predefined_user_data(row_index, grouped_user_sessions.second.first.user)

      grouped_user_sessions.second.each do |user_session|
        user_session.answers.each do |answer|
          answer_attempt = calculate_answer_attempt(answer)
          set_default_value(user_session, answer, row_index, answer_attempt, multiple_fill_indicator_for(user_session.session))
          next if answer.skipped

          answer.body_data&.each do |data|
            var_index = header.index(column_name(multiple_fill_indicator_for(user_session.session), user_session.session, answer.csv_header_name(data),
                                                 answer_attempt))

            next if var_index.blank?

            var_value = answer.csv_row_value(data)
            rows[row_index][var_index] = var_value
          end
        end
        fill_by_tlfb_research(row_index, user_session, calculate_number_of_attempts_for(user_session), multiple_fill_indicator_for(user_session.session))
        metadata(user_session.session, user_session, row_index, calculate_number_of_attempts_for(user_session),
                 multiple_fill_indicator_for(user_session.session))
        quick_exit(user_session.session, row_index, user_session, calculate_number_of_attempts_for(user_session),
                   multiple_fill_indicator_for(user_session.session))
      end

      fill_hf_initial_screen(row_index, grouped_user_sessions.second.first)
    end
  end

  def multiple_fill_indicator_for(session)
    if session.type == 'Session::Sms'
      number_of_attempts(session) > 1
    else
      session.multiple_fill
    end
  end

  def calculate_number_of_attempts_for(user_session)
    session = user_session.session

    if session.type == 'Session::Sms'
      number_of_attempts(session)
    else
      user_session.number_of_attempts
    end
  end

  def calculate_answer_attempt(answer)
    if answer.user_session.session.type == 'Session::Sms'
      ordered_ids = Answer.where(user_session_id: answer.user_session_id, question_id: answer.question_id).order(:created_at).pluck(:id)
      ordered_ids.index(answer.id)
    else
      answer.user_session.number_of_attempts
    end
  end

  def number_of_attempts(session)
    if session.type == 'Session::Sms'
      user_session_ids = user_sessions.where(session_id: session.id).pluck(:id)

      Answer
        .where(user_session_id: user_session_ids)
        .group(:user_session_id, :question_id)
        .unscope(:order)
        .pluck('count(question_id)').max
    else
      user_sessions.where(session_id: session.id).maximum(:number_of_attempts) || 1
    end
  end

  def metadata(session, user_session, row_index, approach_number, multiple_fill)
    session_headers_index = header.index(column_name(multiple_fill, session, 'metadata.session_start', approach_number))
    session_start = user_session.answers.first&.created_at || user_session.created_at
    session_end = user_session.finished_at
    unless session_end.nil?
      rows[row_index][session_headers_index + 2] = time_diff(session_start, session_end) # session duration
      rows[row_index][session_headers_index + 1] = session_end
    end
    rows[row_index][session_headers_index] = session_start
  end

  def quick_exit(session, row_index, user_session, approach_number, multiple_fill)
    session_header_index = header.index(column_name(multiple_fill, session, 'metadata.quick_exit', approach_number))

    rows[row_index][session_header_index] = boolean_to_int(user_session.quick_exit) if session_header_index.present?
  end

  def users
    user_ids = UserSession.where(session_id: session_ids).pluck(:user_id)
    User.where(id: user_ids).includes(:user_sessions)
  end

  def session_ids
    @session_ids ||= sessions.pluck(:id)
  end

  def user_sessions
    @user_sessions ||= UserSession.where(session_id: session_ids).includes(:user)
  end

  def initialize_row
    rows << Array.new(header.size)
  end

  def set_user_data(index, user_session)
    rows[index][0] = user_session.user_id
    rows[index][1] = user_session.user.email
  end

  def set_default_value(user_session, answer, row_index, number_of_attempt, multiple_fill)
    return unless answer.skipped

    answer.question.csv_header_names.each do |variable|
      var_index = header.index(column_name(multiple_fill, user_session.session, variable, number_of_attempt))

      next if var_index.blank?

      rows[row_index][var_index] = DEFAULT_VALUE
    end
  end

  def hf_headers(sessions)
    return [] unless sessions.first&.intervention&.hfhs_access

    hf_initial_question = Question::HenryFordInitial.joins(:question_group).find_by(question_group: { session: sessions })
    return [] if hf_initial_question.nil?

    hf_initial_question.csv_header_names
  end

  def predefined_user_headers(sessions)
    return [] if sessions.first&.intervention&.predefined_user_parameters.blank?

    %i[first_name last_name external_id full_number].map { |column| "predefined_participant.#{column}" }
  end

  def predefined_user_data(row_index, user)
    %i[first_name last_name external_id full_number].each do |column|
      var_index = header.index("predefined_participant.#{column}")
      next if var_index.nil?

      rows[row_index][var_index] = user.send(column)
    end
  end

  def fill_hf_initial_screen(row_index, user_session)
    return unless user_session.session.intervention.hfhs_access

    question = ::Question::HenryFordInitial.joins(:answers).find_by(answers: { user_session: user_session })
    attrs = question&.csv_decoded_attrs
    patient_details = patient_details(user_session, attrs)
    return if patient_details.blank?

    attrs = question.rename_attrs(attrs)
    attrs.each_with_index do |column, index|
      var_index = header.index("henry_ford_health.#{column}")
      next if var_index.nil?

      rows[row_index][var_index] = patient_details[index]
    end
  end

  def patient_details(user_session, attrs)
    details = user_session.user.hfhs_patient_detail&.attributes
    details&.fetch_values(*attrs)
  end

  def column_name(multiple_fill, session, suffix, approach_number = nil)
    if multiple_fill
      "#{session.variable}.approach_number_#{approach_number || 1}.#{suffix}"
    else
      "#{session.variable}.#{suffix}"
    end
  end

  def grouped_and_sorted_user_sessions
    @grouped_and_sorted_user_sessions ||= user_sessions.group_by(&:user_id).sort_by do |grouped_user_sessions_per_user|
      grouped_user_sessions_per_user[1].min_by(&:created_at).created_at
    end
  end
end
