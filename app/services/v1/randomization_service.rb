# frozen_string_literal: true

class V1::RandomizationService
  def initialize(target_array)
    @target_array = target_array
  end

  attr_reader :target_array

  def execute
    return target_array.first if target_array.first['probability'].nil?

    probability = rand(100)
    current_question_probability = 0

    target_array.each do |target|
      current_question_probability += target['probability'].to_i
      return target if probability < current_question_probability
    end
  end
end
