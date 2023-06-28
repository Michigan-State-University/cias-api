# frozen_string_literal: true

module Intervention::Csv::Tlfb
  DEFAULT_VALUE_FOR_TLFB_ANSWER = 0

  def fill_by_tlfb_research(row_index, user_session, index, multiple_fill)
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
          var_index = header.index(column_name(multiple_fill, session, "tlfb.#{consumption['variable']}_d#{day_index + 1}", index))
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
