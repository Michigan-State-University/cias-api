# frozen_string_literal: true

class Question::Grid < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'proceed_button' => true, 'required' => true }
    )
  end

  def harvest_body_variables
    body_data.first['payload']['rows'].map { |row| row['variable']['name'] }
  end
end
