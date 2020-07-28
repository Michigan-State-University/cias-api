# frozen_string_literal: true

class Question::AnalogueScale < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'required' => true, 'show_number' => true }
    )
  end

  def harvest_body_variables
    [body_variable['name']]
  end
end
