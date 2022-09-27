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

  def translate_body(translator, source_language_name_short, destination_language_name_short)
    body['data'].each do |record|
      record['original_text'] = Marshal.load(Marshal.dump(record['payload']))
      %w[question_title head_question substance_question].each do |question_data|
        record['payload'][question_data] = translator.translate(record['payload'][question_data], source_language_name_short, destination_language_name_short)
      end

      if record['payload']['substance_groups'].present?
        record['payload']['substance_groups'].flat_map do |substance_group|
          substance_group['name'] = translator.translate(substance_group['name'], source_language_name_short, destination_language_name_short)
          translate_substances(substance_group['substances'], translator, source_language_name_short, destination_language_name_short)
        end
      elsif record['payload']['substances'].present?
        translate_substances(record['payload']['substances'], translator, source_language_name_short, destination_language_name_short)
      end
    end
  end

  def translate_substances(substances, translator, source_language_name_short, destination_language_name_short)
    substances.flat_map do |substance|
      %w[name unit].each do |property|
        translated = translator.translate(substance[property], source_language_name_short, destination_language_name_short)
        substance[property] = translated
      end
    end
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
end
