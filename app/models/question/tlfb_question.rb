# frozen_string_literal: true

class Question::TlfbQuestion < Question::Tlfb
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      {
        'required' => true
      }
    )
  end

  def question_variables
    if body_data[0]['payload']['substance_groups'].blank? && body_data[0]['payload']['substances'].blank?
      add_column_names_for_simple_question
    elsif body_data[0]['payload']['substances_with_group']
      body_data[0]['payload']['substance_groups'].flat_map do |substance_group|
        add_column_names(substance_group['substances'])
      end
    else
      add_column_names(body_data[0]['payload']['substances'])
    end
  end

  private

  def add_column_names(substances)
    substances.flat_map { |substance| add_variable_for_each_day(substance['variable']) }
  end

  def add_variable_for_each_day(var)
    number_of_days.times.map { |i| "tlfb.#{var}_d#{i + 1}" } # rubocop:disable Performance/TimesMap
  end

  def number_of_days
    question_group.questions.find_by(type: 'Question::TlfbConfig').body_data.first.dig('payload', 'days_count').to_i
  end

  def add_column_names_for_simple_question
    title_as_variable = question_group.title_as_variable
    number_of_days.times.map { |i| "tlfb.#{title_as_variable}_d#{i + 1}" } # rubocop:disable Performance/TimesMap
  end

  def correct_variable_format
    super unless no_substances?
  end

  def special_variable?(var)
    (var.start_with?('tlfb.') && var.include?('_d'))
  end

  def no_substances?
    body['data'][0]['payload']['substances'].empty?
  end
end
