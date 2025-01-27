# frozen_string_literal: true

class Question::FollowUpContact < Question
  include ::Question::CloneableVariable

  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super.merge(
      { 'required' => true }
    )
  end

  def question_variables
    [body['variable']['name']]
  end
end
