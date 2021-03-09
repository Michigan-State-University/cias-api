# frozen_string_literal: true

class Question::Currency < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
        { 'required' => true }
    )
  end

  def harvest_body_variables
    [body_variable['name']]
  end
end
