# frozen_string_literal: true

class Question::Single < Question
  before_validation :assign_custom_values

  private

  def assign_custom_values
    settings['proceed_button'] ||= settings['proceed_button'] = true
  end
end
