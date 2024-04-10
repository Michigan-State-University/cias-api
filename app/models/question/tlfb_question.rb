# frozen_string_literal: true

class Question::TlfbQuestion < Question::Tlfb
  attribute :settings, :json, default: -> { { start_autofinish_timer: false } }

  validates :sms_schedule, absence: true

  def translate_body(translator, source_language_name_short, destination_language_name_short)
    body['data'].each do |record|
      record['original_text'] = record['payload'].deep_dup
      translate_question_data(record, translator, source_language_name_short, destination_language_name_short)

      translate_substances_in_question(record, translator, source_language_name_short, destination_language_name_short)
    end
  end

  def translate_question_data(record, translator, source_language_name_short, destination_language_name_short)
    %w[question_title head_question substance_question].each do |question_data|
      record['payload'][question_data] = translator.translate(record['payload'][question_data], source_language_name_short, destination_language_name_short)
    end
  end

  def translate_substances_in_question(record, translator, source_language_name_short, destination_language_name_short)
    record['payload']['substance_groups']&.each do |substance_group|
      substance_group['name'] = translator.translate(substance_group['name'], source_language_name_short, destination_language_name_short)
      translate_substances(substance_group['substances'], translator, source_language_name_short, destination_language_name_short)
    end

    return if record['payload']['substances'].blank?

    translate_substances(record['payload']['substances'], translator, source_language_name_short, destination_language_name_short)
  end

  def translate_substances(substances, translator, source_language_name_short, destination_language_name_short)
    substances.each do |substance|
      %w[name unit].each do |property|
        translated = translator.translate(substance[property], source_language_name_short, destination_language_name_short)
        substance[property] = translated
      end
    end
  end

  def question_variables
    if substances.empty?
      add_column_names_for_simple_question
    else
      add_column_names(substances)
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

  def substances
    if body_data[0]['payload']['substance_groups'].blank? && body_data[0]['payload']['substances'].blank?
      []
    elsif body_data[0]['payload']['substances_with_group']
      body_data[0]['payload']['substance_groups'].flat_map do |substance_group|
        substance_group['substances']
      end
    else
      body_data[0]['payload']['substances']
    end
  end

  def add_column_names_for_simple_question
    title_as_variable = question_group.title_as_variable
    number_of_days.times.map { |i| "tlfb.#{title_as_variable}_d#{i + 1}" } # rubocop:disable Performance/TimesMap
  end

  def correct_variable_format
    substances.flat_map { |e| e['variable'] }.each do |variable|
      next if /^([a-zA-Z]|[0-9]+[a-zA-Z_]+)[a-zA-Z0-9_\b]*$/.match?(variable)

      errors.add(:base, I18n.t('activerecord.errors.models.question_group.question_variable'))
    end
  end
end
