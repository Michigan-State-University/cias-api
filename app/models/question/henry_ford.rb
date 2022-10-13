# frozen_string_literal: true

class Question::HenryFord < Question::Single
  def question_variables
    super.map { |variable| "hfh.#{variable}" }
  end
end
