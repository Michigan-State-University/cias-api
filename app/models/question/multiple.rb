# frozen_string_literal: true

class Question::Multiple < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'required' => true }
    )
  end

  def harvest_body_variables
    body_data.map { |payload| payload['variable']['name'] }
  end

  def variable_clone_prefix!
    body_data&.each do |payload|
      payload['variable']['name'] = "clone_#{payload['variable']['name']}"
    end
  end
end
