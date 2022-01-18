# frozen_string_literal: true

class Question::TlfbConfig < Question::Tlfb
  attribute :narrator, :json, default: {
    'settings' => {
      'voice' => false,
      'animation' => false
    },
    'blocks' => []
  }
end
