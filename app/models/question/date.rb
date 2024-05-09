# frozen_string_literal: true

class Question::Date < Question
  include ::Question::CloneableVariable

  attribute :settings, :json, default: -> { assign_default_values('settings') }

  validates :accepted_answers, absence: true

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'required' => true }
    )
  end

  def question_variables
    [body['variable']['name']]
  end
end
