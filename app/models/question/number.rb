# frozen_string_literal: true

class Question::Number < Question
  include ::Question::CloneableVariable

  attribute :settings, :json, default: -> { assign_default_values('settings') }

  validates :accepted_answers, absence: true

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'required' => true,
        'max_length' => nil,
        'min_length' => nil }
    )
  end

  def question_variables
    [body['variable']['name']]
  end
end
