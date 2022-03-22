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
    if body_data[0]['payload']['substances_with_group']
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
end
