# frozen_string_literal: true

class Question::Number < Question
  before_validation :assign_custom_values

  private

  def assign_custom_values
    settings['required'] ||= settings['required'] = true
  end
end
