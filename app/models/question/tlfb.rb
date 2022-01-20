# frozen_string_literal: true

class Question::Tlfb < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      {
        'title' => false,
        'subtitle' => false
      }
    )
  end
end
