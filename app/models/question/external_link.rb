# frozen_string_literal: true

class Question::ExternalLink < Question
  include ::Question::CloneableVariable

  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def question_variables
    [body['variable']['name']]
  end
end
