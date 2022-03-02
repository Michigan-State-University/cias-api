# frozen_string_literal: true

class Question::TlfbQuestion < Question::Tlfb
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      {
        'required' => true
      }
    )
  end
end
