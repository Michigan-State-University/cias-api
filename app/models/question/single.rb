# frozen_string_literal: true

class Question::Single < Question
  before_validation :assign_custom_values

  private

  def assign_custom_values
    settings['proceed_button'] = true if settings['proceed_button'].nil?
    settings['required'] = true if settings['required'].nil?
  end
end
