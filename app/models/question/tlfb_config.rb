# frozen_string_literal: true

class Question::TlfbConfig < Question::Tlfb
  attribute :narrator, :json, default: {
    'settings' => {
      'voice' => false,
      'animation' => false
    },
    'blocks' => []
  }

  def prepare_to_display(_answers_var_values = nil)
    question_to_display = question_group.questions.second
    question_to_display.apply_config(body)
    question_to_display
  end
end