# frozen_string_literal: true

class Question::Number < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'required' => true }
    )
  end

  def variable_clone_prefix
    body['variable']['name'] = "clone_#{body['variable']['name']}" if body['variable']['name'].presence
  end
end
