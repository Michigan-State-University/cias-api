# frozen_string_literal: true

class Question::Url < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def variable_clone_prefix
    body['variable']['name'] = "clone_#{body['variable']['name']}"
  end
end
