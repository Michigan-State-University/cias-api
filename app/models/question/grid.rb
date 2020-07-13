# frozen_string_literal: true

class Question::Grid < Question
  before_validation :assign_custom_values

  private

  def assign_custom_values
    settings['proceed_button'] ||= settings['proceed_button'] = true
    settings['required'] ||= settings['required'] = true
  end
end
