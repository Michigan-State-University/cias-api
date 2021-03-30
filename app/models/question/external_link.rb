# frozen_string_literal: true

class Question::ExternalLink < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def variable_clone_prefix
    body['variable']['name'] = "clone_#{body['variable']['name']}" if body['variable']['name'].presence
  end
end
