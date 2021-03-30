# frozen_string_literal: true

class Question::Single < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'proceed_button' => true, 'required' => true }
    )
  end

  def variable_clone_prefix
    body['variable']['name'] = "clone_#{body['variable']['name']}" if body['variable']['name'].presence
  end
end
