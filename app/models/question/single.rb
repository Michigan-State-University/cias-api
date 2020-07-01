# frozen_string_literal: true

class Question::Single < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def body_text_harvester
    body_data.map { |item| item['payload'] }
  end

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'proceed_button' => true, 'required' => true }
    )
  end
end
