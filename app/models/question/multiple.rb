# frozen_string_literal: true

class Question::Multiple < Question
  before_validation :assign_custom_values

  private

  def assign_custom_values
    settings['required'] = true if settings['required'].nil?
  end
end
