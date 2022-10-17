# frozen_string_literal: true

class Question::HenryFord < Question::Single
  def question_variables
    super.map { |variable| "henry_ford_health.#{variable}" }
  end
end
