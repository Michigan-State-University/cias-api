# frozen_string_literal: true

class Question::TlfbConfig < Question::Tlfb
  attribute :narrator, :json, default: {
    'settings' => {
      'voice' => false,
      'animation' => false,
      'character' => 'peedy'
    },
    'blocks' => []
  }

  validates :sms_schedule, absence: true

  def prepare_to_display(_answers_var_values = nil)
    question_to_display = question_group.questions.second
    question_to_display.apply_config(body)
    question_to_display
  end

  def first_question?
    false
  end
end
